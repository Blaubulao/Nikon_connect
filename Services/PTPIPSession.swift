import Foundation

actor PTPIPSession {
    private let host: String
    private let port: UInt16
    private let commandConnection: PTPIPTCPConnection
    private let eventConnection: PTPIPTCPConnection
    private let commandGate = CommandChannelGate()
    private let initiatorGUID: Data

    private var responderFriendlyName = "Nikon 相机"
    private var connectionNumber: UInt32?
    private var nextTransactionID: UInt32 = 1
    private var isOpen = false
    private var diagnostics: [String] = []
    private var assetTraversalState: AssetTraversalState?
    private var thumbnailOperationSupport: ThumbnailOperationSupport = .unknown

    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
        self.commandConnection = PTPIPTCPConnection(host: host, port: port)
        self.eventConnection = PTPIPTCPConnection(host: host, port: port)
        self.initiatorGUID = Self.loadOrCreateInitiatorGUID()
    }

    func establishConnection() async throws -> PTPIPDeviceInfo {
        recordDiagnostic("准备连接 \(host):\(port) ...")
        try await commandConnection.open()
        recordDiagnostic("命令通道已连接。")
        try await commandConnection.send(
            PTPIPBinary.encodeInitCommandRequest(
                guid: initiatorGUID,
                friendlyName: PTPIPBinary.defaultFriendlyName
            )
        )

        let commandAck = try await commandConnection.receivePacket()
        switch commandAck.type {
        case .initCommandAck:
            let ack = try parseInitCommandAck(commandAck.payload)
            connectionNumber = ack.connectionNumber
            responderFriendlyName = ack.responderFriendlyName.isEmpty ? responderFriendlyName : ack.responderFriendlyName
            recordDiagnostic(
                "InitCommandAck: connection=\(ack.connectionNumber) name=\(responderFriendlyName)"
            )
            guard ack.protocolVersion >> 16 == 0x0001 else {
                throw PTPIPError.invalidProtocolVersion(ack.protocolVersion)
            }
        case .initFail:
            throw PTPIPError.malformedPayload("相机拒绝了 PTP/IP 连接请求。")
        default:
            throw PTPIPError.unexpectedPacket(expected: [.initCommandAck, .initFail], actual: commandAck.type)
        }

        guard let connectionNumber else {
            throw PTPIPError.sessionUnavailable
        }

        try await eventConnection.open()
        recordDiagnostic("事件通道已连接。")
        try await eventConnection.send(PTPIPBinary.encodeInitEventRequest(connectionNumber: connectionNumber))

        let eventAck = try await eventConnection.receivePacket()
        switch eventAck.type {
        case .initEventAck:
            recordDiagnostic("InitEventAck: PTP/IP 双通道握手完成。")
            break
        case .initFail:
            throw PTPIPError.malformedPayload("相机拒绝了 Event 通道连接。")
        default:
            throw PTPIPError.unexpectedPacket(expected: [.initEventAck, .initFail], actual: eventAck.type)
        }

        let deviceInfoData = try await requestDataIn(
            operation: .getDeviceInfo,
            transactionID: 0,
            parameters: []
        )
        let deviceInfo = try parseDeviceInfo(deviceInfoData)
        let deviceName = [deviceInfo.manufacturer, deviceInfo.model]
            .compactMap { $0 }
            .joined(separator: " ")
        if !deviceName.isEmpty {
            recordDiagnostic("设备信息: \(deviceName)")
        }

        _ = try await requestResponseOnly(
            operation: .openSession,
            transactionID: 0,
            parameters: [1]
        )
        recordDiagnostic("OpenSession 成功。")

        nextTransactionID = 1
        isOpen = true
        return deviceInfo
    }

    func close() async {
        if isOpen {
            do {
                _ = try await requestResponseOnly(
                    operation: .closeSession,
                    transactionID: nextTransactionID,
                    parameters: []
                )
            } catch {
                AppLogger.transport.warning("Failed to close PTP session cleanly: \(error.localizedDescription, privacy: .public)")
            }
        }

        await commandConnection.close()
        await eventConnection.close()
        assetTraversalState = nil
        thumbnailOperationSupport = .unknown
        isOpen = false
    }

    func fetchAssetsPage(limit: Int, resetTraversal: Bool) async throws -> PhotoAssetPage {
        try ensureOpen()

        let pageSize = max(1, limit)
        if resetTraversal || assetTraversalState == nil {
            assetTraversalState = try await prepareAssetTraversalState()
        }

        guard var traversal = assetTraversalState else {
            throw PTPIPError.sessionUnavailable
        }

        var pageAssets: [PhotoAsset] = []
        var unsupportedObjects: [(UInt32, UInt16, String)] = []

        while pageAssets.count < pageSize, traversal.nextIndex < traversal.queue.count {
            let handle = traversal.queue[traversal.nextIndex]
            traversal.nextIndex += 1

            let info = try await fetchObjectInfo(handle: handle)

            switch classifyObject(info) {
            case .asset(let asset):
                if traversal.loadedAssetHandles.insert(info.handle).inserted {
                    pageAssets.append(asset)
                }

            case .directory:
                if traversal.exploredDirectoryHandles.insert(info.handle).inserted {
                    let childHandles = await loadChildHandles(
                        parentHandle: handle,
                        storageID: info.storageID
                    )
                    let childPreview = childHandles.prefix(5).map(String.init).joined(separator: ", ")
                    recordDiagnostic(
                        "目录 \(info.fileName) handle=\(handle) 子对象 \(childHandles.count) 个" +
                        (childPreview.isEmpty ? "" : " [\(childPreview)]")
                    )

                    var newChildren: [UInt32] = []
                    newChildren.reserveCapacity(childHandles.count)
                    for child in childHandles where traversal.seenHandles.insert(child).inserted {
                        newChildren.append(child)
                    }

                    if !newChildren.isEmpty {
                        traversal.queue.insert(contentsOf: newChildren, at: traversal.nextIndex)
                    }
                }

            case .unsupported(let unsupported):
                if traversal.unsupportedHandles.insert(unsupported.0).inserted {
                    unsupportedObjects.append(unsupported)
                }
            }
        }

        if !unsupportedObjects.isEmpty {
            let preview = unsupportedObjects
                .prefix(3)
                .map { "handle=\($0.0) format=0x\(String($0.1, radix: 16)) name=\($0.2)" }
                .joined(separator: " | ")
            recordDiagnostic("本批未识别对象 \(unsupportedObjects.count) 个。\(preview)")
        }

        let hasMore = traversal.nextIndex < traversal.queue.count
        let summary = hasMore
            ? "本批读取 \(pageAssets.count) 张，累计 \(traversal.loadedAssetHandles.count) 张，仍可继续读取。"
            : "本批读取 \(pageAssets.count) 张，累计 \(traversal.loadedAssetHandles.count) 张，当前列表已读完。"
        recordDiagnostic(summary)

        assetTraversalState = traversal

        return PhotoAssetPage(assets: pageAssets, hasMore: hasMore)
    }

    func downloadAsset(handle: UInt32) async throws -> Data {
        try ensureOpen()
        recordDiagnostic("开始下载对象 handle=\(handle)")
        return try await requestDataIn(
            operation: .getObject,
            transactionID: consumeTransactionID(),
            parameters: [handle]
        )
    }

    func downloadThumbnail(handle: UInt32) async throws -> Data? {
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

    func consumeDiagnostics() -> [String] {
        let current = diagnostics
        diagnostics.removeAll()
        return current
    }

    private func loadStorageIDs() async throws -> [UInt32] {
        let data = try await requestDataIn(
            operation: .getStorageIDs,
            transactionID: consumeTransactionID(),
            parameters: []
        )
        var reader = PTPDataReader(data: data)
        let storageIDs = try reader.readPTPArrayUInt32()
        let preview = storageIDs.map { String(format: "0x%08X", $0) }.joined(separator: ", ")
        recordDiagnostic("StorageIDs(\(storageIDs.count)): \(preview.isEmpty ? "<empty>" : preview)")
        return storageIDs
    }

    private func loadObjectHandles(storageIDs: [UInt32]) async throws -> [UInt32] {
        var merged: [UInt32] = []
        var seen = Set<UInt32>()

        let strategies: [(UInt32, UInt32, UInt32)] = [
            (0xFFFF_FFFF, 0, 0xFFFF_FFFF),
            (0xFFFF_FFFF, 0, 0),
        ]

        for strategy in strategies {
            do {
                let handles = try await requestObjectHandles(strategy: strategy)
                recordDiagnostic("全局句柄策略 \(formatStrategy(strategy)) -> \(handles.count) 个对象")
                for handle in handles where seen.insert(handle).inserted {
                    merged.append(handle)
                }
            } catch {
                recordDiagnostic("全局句柄策略 \(formatStrategy(strategy)) 失败: \(error.localizedDescription)")
            }
        }

        for storageID in storageIDs {
            for associationHandle: UInt32 in [0xFFFF_FFFF, 0] {
                do {
                    let strategy = (storageID, UInt32(0), associationHandle)
                    let handles = try await requestObjectHandles(strategy: strategy)
                    recordDiagnostic("存储句柄策略 \(formatStrategy(strategy)) -> \(handles.count) 个对象")
                    for handle in handles where seen.insert(handle).inserted {
                        merged.append(handle)
                    }
                } catch {
                    let strategy = (storageID, UInt32(0), associationHandle)
                    recordDiagnostic("存储句柄策略 \(formatStrategy(strategy)) 失败: \(error.localizedDescription)")
                }
            }
        }

        return merged.sorted(by: >)
    }

    private func prepareAssetTraversalState() async throws -> AssetTraversalState {
        let storageIDs = try await loadStorageIDs()
        let handles = try await loadObjectHandles(storageIDs: storageIDs)
        recordDiagnostic("准备分批读取照片，首轮候选对象 \(handles.count) 个。")
        return AssetTraversalState(
            queue: handles,
            nextIndex: 0,
            seenHandles: Set(handles),
            loadedAssetHandles: [],
            exploredDirectoryHandles: [],
            unsupportedHandles: []
        )
    }

    private func requestObjectHandles(strategy: (UInt32, UInt32, UInt32)) async throws -> [UInt32] {
        let data = try await requestDataIn(
            operation: .getObjectHandles,
            transactionID: consumeTransactionID(),
            parameters: [strategy.0, strategy.1, strategy.2]
        )
        var reader = PTPDataReader(data: data)
        return try reader.readPTPArrayUInt32()
    }

    private func fetchObjectInfo(handle: UInt32) async throws -> PTPIPObjectInfo {
        let data = try await requestDataIn(
            operation: .getObjectInfo,
            transactionID: consumeTransactionID(),
            parameters: [handle]
        )

        return try parseObjectInfo(data: data, handle: handle)
    }

    private func classifyObject(_ info: PTPIPObjectInfo) -> ObjectClassification {
        if info.objectFormat == 0x3001 {
            return .directory
        }

        guard let kind = photoKind(for: info) else {
            return .unsupported((info.handle, info.objectFormat, info.fileName))
        }

        return .asset(
            PhotoAsset(
                remoteIdentifier: String(info.handle),
                fileName: info.fileName,
                kind: kind,
                byteSize: Int64(info.compressedSize),
                captureDate: info.captureDate ?? info.modificationDate ?? .distantPast,
                thumbnailInfo: info.thumbnailInfo
            )
        )
    }

    private func loadChildHandles(parentHandle: UInt32, storageID: UInt32) async -> [UInt32] {
        let strategies: [(UInt32, UInt32, UInt32)] = [
            (storageID, 0, parentHandle),
            (0xFFFF_FFFF, 0, parentHandle),
        ]

        var merged: [UInt32] = []
        var seen = Set<UInt32>()

        for strategy in strategies {
            do {
                let handles = try await requestObjectHandles(strategy: strategy)
                recordDiagnostic("子句柄策略 \(formatStrategy(strategy)) -> \(handles.count) 个对象")
                for handle in handles where seen.insert(handle).inserted {
                    merged.append(handle)
                }
            } catch {
                recordDiagnostic("子句柄策略 \(formatStrategy(strategy)) 失败: \(error.localizedDescription)")
            }
        }

        return merged.sorted(by: >)
    }

    private func requestResponseOnly(
        operation: PTPOperationCode,
        transactionID: UInt32,
        parameters: [UInt32]
    ) async throws -> PTPIPResponse {
        let commandConnection = self.commandConnection
        return try await commandGate.withExclusiveAccess {
            try await commandConnection.send(
                PTPIPBinary.encodeOperationRequest(
                    operation: operation,
                    transactionID: transactionID,
                    parameters: parameters,
                    dataPhase: .noDataOrDataIn
                )
            )

            let packet = try await commandConnection.receivePacket()
            let response = try PTPIPBinary.parseResponsePacket(packet)
            try Self.validateResponse(response, expectedTransactionID: transactionID)
            return response
        }
    }

    private func requestDataIn(
        operation: PTPOperationCode,
        transactionID: UInt32,
        parameters: [UInt32]
    ) async throws -> Data {
        let commandConnection = self.commandConnection
        return try await commandGate.withExclusiveAccess {
            try await commandConnection.send(
                PTPIPBinary.encodeOperationRequest(
                    operation: operation,
                    transactionID: transactionID,
                    parameters: parameters,
                    dataPhase: .noDataOrDataIn
                )
            )

            let firstPacket = try await commandConnection.receivePacket()
            switch firstPacket.type {
            case .operationResponse:
                let response = try PTPIPBinary.parseResponsePacket(firstPacket)
                try Self.validateResponse(response, expectedTransactionID: transactionID)
                return Data()

            case .startData:
                let start = try PTPIPBinary.parseStartDataPayload(firstPacket.payload)
                guard start.transactionID == transactionID else {
                    throw PTPIPError.invalidTransaction(expected: transactionID, actual: start.transactionID)
                }

                var collected = Data()
                while true {
                    let packet = try await commandConnection.receivePacket(timeoutSeconds: 30)
                    switch packet.type {
                    case .data:
                        let part = try PTPIPBinary.parseDataPayload(packet.payload)
                        guard part.transactionID == transactionID else {
                            throw PTPIPError.invalidTransaction(expected: transactionID, actual: part.transactionID)
                        }
                        collected.append(part.bytes)

                    case .endData:
                        let part = try PTPIPBinary.parseDataPayload(packet.payload)
                        guard part.transactionID == transactionID else {
                            throw PTPIPError.invalidTransaction(expected: transactionID, actual: part.transactionID)
                        }
                        collected.append(part.bytes)

                        let responsePacket = try await commandConnection.receivePacket(timeoutSeconds: 30)
                        let response = try PTPIPBinary.parseResponsePacket(responsePacket)
                        try Self.validateResponse(response, expectedTransactionID: transactionID)

                        if start.totalLength != UInt64.max, start.totalLength != UInt64(collected.count) {
                            AppLogger.transport.warning(
                                "PTP object length mismatch. expected=\(start.totalLength) actual=\(collected.count)"
                            )
                        }

                        return collected

                    case .operationResponse:
                        let response = try PTPIPBinary.parseResponsePacket(packet)
                        try Self.validateResponse(response, expectedTransactionID: transactionID)
                        return collected

                    default:
                        throw PTPIPError.unexpectedPacket(
                            expected: [.data, .endData, .operationResponse],
                            actual: packet.type
                        )
                    }
                }

            default:
                throw PTPIPError.unexpectedPacket(expected: [.operationResponse, .startData], actual: firstPacket.type)
            }
        }
    }

    private static func validateResponse(_ response: PTPIPResponse, expectedTransactionID: UInt32) throws {
        guard response.transactionID == expectedTransactionID else {
            throw PTPIPError.invalidTransaction(expected: expectedTransactionID, actual: response.transactionID)
        }

        guard response.code == PTPResponseCode.ok.rawValue else {
            throw PTPIPError.unexpectedResponse(code: response.code)
        }
    }

    private func parseInitCommandAck(_ payload: Data) throws -> (
        connectionNumber: UInt32,
        responderGUID: Data,
        responderFriendlyName: String,
        protocolVersion: UInt32
    ) {
        var reader = PTPDataReader(data: payload)
        let connectionNumber = try reader.readUInt32()
        let responderGUID = try reader.readData(count: 16)
        let responderFriendlyName = try reader.readUTF16NullTerminatedString()
        let protocolVersion = try reader.readUInt32()
        return (connectionNumber, responderGUID, responderFriendlyName, protocolVersion)
    }

    private func parseDeviceInfo(_ data: Data) throws -> PTPIPDeviceInfo {
        var reader = PTPDataReader(data: data)
        _ = try reader.readUInt16()
        _ = try reader.readUInt32()
        _ = try reader.readUInt16()
        _ = try reader.readPTPString()
        _ = try reader.readUInt16()
        _ = try reader.readPTPArrayUInt16()
        _ = try reader.readPTPArrayUInt16()
        _ = try reader.readPTPArrayUInt16()
        _ = try reader.readPTPArrayUInt16()
        _ = try reader.readPTPArrayUInt16()
        let manufacturer = try reader.readPTPString()
        let model = try reader.readPTPString()
        _ = try reader.readPTPString()
        _ = try reader.readPTPString()
        return PTPIPDeviceInfo(
            model: model.isEmpty ? nil : model,
            manufacturer: manufacturer.isEmpty ? nil : manufacturer
        )
    }

    private func parseObjectInfo(data: Data, handle: UInt32) throws -> PTPIPObjectInfo {
        var reader = PTPDataReader(data: data)
        let storageID = try reader.readUInt32()
        let objectFormat = try reader.readUInt16()
        _ = try reader.readUInt16()
        let compressedSize = try reader.readUInt32()
        let thumbFormat = try reader.readUInt16()
        let thumbCompressedSize = try reader.readUInt32()
        let thumbPixWidth = try reader.readUInt32()
        let thumbPixHeight = try reader.readUInt32()
        _ = try reader.readUInt32()
        _ = try reader.readUInt32()
        _ = try reader.readUInt32()
        _ = try reader.readUInt32()
        _ = try reader.readUInt16()
        _ = try reader.readUInt32()
        _ = try reader.readUInt32()
        let fileName = try reader.readPTPString()
        let captureDate = Self.parsePTPDate(try reader.readPTPString())
        let modificationDate = Self.parsePTPDate(try reader.readPTPString())
        _ = try? reader.readPTPString()

        let thumbnailInfo: PhotoAssetThumbnailInfo? =
            thumbCompressedSize > 0
            ? PhotoAssetThumbnailInfo(
                formatCode: thumbFormat,
                byteSize: Int64(thumbCompressedSize),
                pixelWidth: Int(thumbPixWidth),
                pixelHeight: Int(thumbPixHeight)
            )
            : nil

        return PTPIPObjectInfo(
            handle: handle,
            storageID: storageID,
            objectFormat: objectFormat,
            compressedSize: compressedSize,
            thumbnailInfo: thumbnailInfo,
            fileName: fileName,
            captureDate: captureDate,
            modificationDate: modificationDate
        )
    }

    private func photoKind(for info: PTPIPObjectInfo) -> PhotoAssetKind? {
        let ext = URL(fileURLWithPath: info.fileName).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg":
            return .jpeg
        case "png":
            return .png
        case "nef", "nrw", "raw":
            return .raw
        case "mov", "mp4":
            return .movie
        default:
            break
        }

        switch info.objectFormat {
        case 0x3801:
            return .jpeg
        case 0x380B:
            return .png
        case 0x380D, 0x3802, 0x3810, 0x3811:
            return .raw
        default:
            return nil
        }
    }

    private func consumeTransactionID() -> UInt32 {
        let current = nextTransactionID
        nextTransactionID += 1
        return current
    }

    private func ensureOpen() throws {
        guard isOpen else { throw PTPIPError.sessionUnavailable }
    }

    private func recordDiagnostic(_ message: String) {
        diagnostics.append(message)
        AppLogger.transport.info("\(message, privacy: .public)")
    }

    private func formatStrategy(_ strategy: (UInt32, UInt32, UInt32)) -> String {
        let storage = String(format: "0x%08X", strategy.0)
        let format = String(format: "0x%08X", strategy.1)
        let association = String(format: "0x%08X", strategy.2)
        return "[storage=\(storage) format=\(format) assoc=\(association)]"
    }

    private static func loadOrCreateInitiatorGUID() -> Data {
        let defaults = UserDefaults.standard
        let key = "ptpipInitiatorGUID"
        if let saved = defaults.data(forKey: key), saved.count == 16 {
            return saved
        }

        let uuid = UUID().uuid
        let data = withUnsafeBytes(of: uuid) { Data($0) }
        defaults.set(data, forKey: key)
        return data
    }

    private static func parsePTPDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }

        let trimmed = String(value.prefix(15))
        guard trimmed.count >= 15 else { return nil }

        let year = Int(trimmed.prefix(4))
        let month = Int(trimmed.dropFirst(4).prefix(2))
        let day = Int(trimmed.dropFirst(6).prefix(2))
        let hour = Int(trimmed.dropFirst(9).prefix(2))
        let minute = Int(trimmed.dropFirst(11).prefix(2))
        let second = Int(trimmed.dropFirst(13).prefix(2))

        guard
            let year,
            let month,
            let day,
            let hour,
            let minute,
            let second
        else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.current
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return components.date
    }
}

private actor CommandChannelGate {
    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func withExclusiveAccess<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        await acquire()
        defer { release() }
        return try await operation()
    }

    private func acquire() async {
        guard isBusy else {
            isBusy = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard !waiters.isEmpty else {
            isBusy = false
            return
        }

        let next = waiters.removeFirst()
        next.resume()
    }
}

private enum ThumbnailOperationSupport {
    case unknown
    case supported
    case unsupported
}

private enum ObjectClassification {
    case asset(PhotoAsset)
    case directory
    case unsupported((UInt32, UInt16, String))
}

private struct AssetTraversalState {
    var queue: [UInt32]
    var nextIndex: Int
    var seenHandles: Set<UInt32>
    var loadedAssetHandles: Set<UInt32>
    var exploredDirectoryHandles: Set<UInt32>
    var unsupportedHandles: Set<UInt32>
}
