import Foundation

extension PTPIPSession {
    func downloadAssetPayload(handle: UInt32) async throws -> Data {
        try ensureOpen()
        switch downloadStrategy {
        case .fullObject:
            recordDiagnostic("开始整包下载对象 handle=\(handle)")
            return try await requestDataIn(
                operation: .getObject,
                transactionID: consumeTransactionID(),
                parameters: [handle]
            )

        case .partialObject(let chunkSize):
            let objectInfo = try await fetchObjectInfo(handle: handle)
            let totalLength = UInt64(objectInfo.compressedSize)
            var collected = Data(capacity: Int(totalLength))
            recordDiagnostic("开始分块下载对象 handle=\(handle)，chunk=\(chunkSize)")
            try await downloadObjectInChunks(
                handle: handle,
                totalLength: totalLength,
                chunkSize: chunkSize
            ) { chunk in
                collected.append(chunk)
            }
            return collected
        }
    }

    func downloadAssetToTemporaryFilePayload(
        handle: UInt32,
        suggestedFileName: String,
        onProgress: (@Sendable (DownloadTransferProgress) async -> Void)?
    ) async throws -> URL {
        try ensureOpen()
        switch downloadStrategy {
        case .fullObject:
            recordDiagnostic("开始流式整包下载对象 handle=\(handle)")
            return try await requestDataInToTemporaryFile(
                operation: .getObject,
                transactionID: consumeTransactionID(),
                parameters: [handle],
                suggestedFileName: suggestedFileName
            )

        case .partialObject(let chunkSize):
            let objectInfo = try await fetchObjectInfo(handle: handle)
            let totalLength = UInt64(objectInfo.compressedSize)
            recordDiagnostic("开始分块流式下载对象 handle=\(handle)，chunk=\(chunkSize)")
            return try await downloadObjectToTemporaryFileInChunks(
                handle: handle,
                totalLength: totalLength,
                suggestedFileName: suggestedFileName,
                chunkSize: chunkSize,
                onProgress: onProgress
            )
        }
    }

    func loadThumbnailData(handle: UInt32) async throws -> Data? {
        try ensureOpen()

        if thumbnailOperationSupport == .unsupported {
            return nil
        }

        recordDiagnostic("开始读取缩略图 handle=\(handle)")

        do {
            let data = try await requestDataIn(
                operation: .getThumb,
                transactionID: consumeTransactionID(),
                parameters: [handle]
            )
            thumbnailOperationSupport = .supported
            return data.isEmpty ? nil : data
        } catch let error as PTPIPError {
            switch error {
            case .unexpectedResponse(code: PTPResponseCode.noThumbnailPresent.rawValue):
                thumbnailOperationSupport = .supported
                recordDiagnostic("对象 handle=\(handle) 没有可用缩略图。")
                return nil
            case .unexpectedResponse(code: PTPResponseCode.operationNotSupported.rawValue):
                thumbnailOperationSupport = .unsupported
                recordDiagnostic("相机未公开 GetThumb，将回退到原始文件读取。")
                return nil
            default:
                throw error
            }
        }
    }

    func configureDownloadStrategy(using deviceInfo: PTPIPDeviceInfo) {
        if deviceInfo.supportsOperation(.getPartialObject) {
            downloadStrategy = .partialObject(chunkSize: Self.defaultChunkSize)
            recordDiagnostic("相机支持 GetPartialObject，启用分块可恢复下载。")
        } else {
            downloadStrategy = .fullObject
            recordDiagnostic("相机未声明 GetPartialObject，回退为整包下载。")
        }
    }

    func downloadObjectInChunks(
        handle: UInt32,
        totalLength: UInt64,
        chunkSize: Int,
        onChunk: (Data) throws -> Void,
        onProgress: (@Sendable (DownloadTransferProgress) async -> Void)? = nil
    ) async throws {
        if totalLength == 0 {
            return
        }

        guard totalLength <= UInt64(UInt32.max) else {
            throw CameraAppError.unsupportedOperation("当前版本暂不支持大于 4 GiB 的可恢复下载。")
        }

        try await withExclusiveCommandChannelAccess {
            var offset: UInt64 = 0
            var retryCount = 0
            var resumedCount = 0

            while offset < totalLength {
                let remaining = totalLength - offset
                let requestLength = min(UInt64(chunkSize), remaining)

                do {
                    let payload = try await requestDataInDirect(
                        operation: .getPartialObject,
                        transactionID: consumeTransactionID(),
                        parameters: [handle, UInt32(offset), UInt32(requestLength)]
                    )
                    guard !payload.isEmpty else {
                        throw PTPIPError.malformedPayload("GetPartialObject 返回了空数据。")
                    }

                    try onChunk(payload)
                    offset += UInt64(payload.count)
                    retryCount = 0

                    if let onProgress {
                        await onProgress(
                            DownloadTransferProgress(
                                bytesTransferred: Int64(offset),
                                totalBytes: Int64(totalLength),
                                resumedCount: resumedCount,
                                currentOffset: Int64(offset),
                                chunkSize: Int64(requestLength)
                            )
                        )
                    }
                } catch {
                    guard shouldRetryChunkTransfer(after: error), retryCount < Self.maxChunkRetryCount else {
                        throw error
                    }

                    retryCount += 1
                    resumedCount += 1

                    if let onProgress {
                        await onProgress(
                            DownloadTransferProgress(
                                bytesTransferred: Int64(offset),
                                totalBytes: Int64(totalLength),
                                resumedCount: resumedCount,
                                currentOffset: Int64(offset),
                                chunkSize: Int64(requestLength)
                            )
                        )
                    }

                    try await prepareChunkRetry(
                        after: error,
                        offset: offset,
                        totalLength: totalLength,
                        attempt: retryCount
                    )
                }
            }
        }
    }

    func downloadObjectToTemporaryFileInChunks(
        handle: UInt32,
        totalLength: UInt64,
        suggestedFileName: String,
        chunkSize: Int,
        onProgress: (@Sendable (DownloadTransferProgress) async -> Void)?
    ) async throws -> URL {
        let temporaryURL = Self.makeTemporaryDownloadURL(suggestedFileName: suggestedFileName)
        guard let outputStream = OutputStream(url: temporaryURL, append: false) else {
            throw CameraAppError.fileSystemFailure("无法创建临时下载文件。")
        }

        outputStream.open()
        defer { outputStream.close() }

        do {
            try await downloadObjectInChunks(
                handle: handle,
                totalLength: totalLength,
                chunkSize: chunkSize
            ) { chunk in
                try Self.write(chunk, to: outputStream)
            } onProgress: { progress in
                if let onProgress {
                    await onProgress(progress)
                }
            }
            return temporaryURL
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    func shouldRetryChunkTransfer(after error: Error) -> Bool {
        guard let ptpError = error as? PTPIPError else {
            return false
        }

        switch ptpError {
        case .timeout, .connectionClosed:
            return true
        case .unexpectedResponse(let code):
            return code == PTPResponseCode.deviceBusy.rawValue ||
                code == PTPResponseCode.incompleteTransfer.rawValue ||
                code == PTPResponseCode.transactionCancelled.rawValue
        default:
            return false
        }
    }

    func prepareChunkRetry(
        after error: Error,
        offset: UInt64,
        totalLength: UInt64,
        attempt: Int
    ) async throws {
        recordDiagnostic(
            "分块传输在 \(offset)/\(totalLength) 处中断，准备第 \(attempt) 次恢复：\(error.localizedDescription)"
        )

        if case PTPIPError.unexpectedResponse(code: PTPResponseCode.deviceBusy.rawValue) = error {
            try await Task.sleep(nanoseconds: UInt64(attempt) * 50_000_000)
            return
        }

        _ = try await openSessionSequence(reason: "断流恢复")
    }

    static func makeTemporaryDownloadURL(suggestedFileName: String) -> URL {
        let ext = URL(fileURLWithPath: suggestedFileName).pathExtension
        let fileName = ext.isEmpty ? UUID().uuidString : UUID().uuidString + "." + ext
        return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }

    static func write(_ data: Data, to outputStream: OutputStream) throws {
        if data.isEmpty {
            return
        }

        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }

            var offset = 0
            while offset < data.count {
                let written = outputStream.write(baseAddress.advanced(by: offset), maxLength: data.count - offset)
                if written < 0 {
                    throw CameraAppError.fileSystemFailure(
                        outputStream.streamError?.localizedDescription ?? "写入临时下载文件失败。"
                    )
                }
                if written == 0 {
                    throw CameraAppError.fileSystemFailure("写入临时下载文件时没有写入任何数据。")
                }
                offset += written
            }
        }
    }
}
