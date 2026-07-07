import Foundation
import SwiftUI

struct ActiveDownloadProgress: Equatable {
    let fileName: String
    let currentItemNumber: Int
    let totalItemCount: Int
    let bytesTransferred: Int64
    let totalBytes: Int64
    let resumedCount: Int
    let currentOffset: Int64
    let chunkSize: Int64

    var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0 }
        let progress = Double(bytesTransferred) / Double(totalBytes)
        return min(max(progress, 0), 1)
    }

    var percentageText: String {
        "\(Int((fractionCompleted * 100).rounded()))%"
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var hostInput: String
    @Published var portInput: String
    @Published var transportMode: CameraTransportMode
    @Published var autoExportToPhotoLibrary: Bool

    @Published var workflowState: CameraWorkflowState = .waitingForWifi
    @Published var activeSession: CameraSession?
    @Published var photoAssets: [PhotoAsset] = []
    @Published var hasMorePhotos = false
    @Published var selectedAssetIDs: Set<UUID> = []
    @Published var downloads: [DownloadRecord] = []
    @Published var downloadDirectoryPath = ""
    @Published var activityLog: [LogEntry] = []
    @Published var alertContext: AlertContext?
    @Published var activeDownloadProgress: ActiveDownloadProgress?
    @Published var lastSummary = "先在系统设置里连接 Nikon 相机的 Wi‑Fi，然后回到这里开始。"
    @Published var isWorking = false

    private let preferencesStore: AppPreferencesStore
    private let transportFactory: CameraTransportFactory
    private let downloadStore: DownloadStore
    private let photoLibraryExportService: any PhotoLibraryExporting
    private let thumbnailService = AssetThumbnailService()
    private let photoPageSize = 60
    private var activeTransport: (any CameraTransport)?
    private var didBootstrap = false

    init(
        preferencesStore: AppPreferencesStore = AppPreferencesStore(),
        transportFactory: CameraTransportFactory = CameraTransportFactory(),
        downloadStore: DownloadStore = DownloadStore(),
        photoLibraryExportService: any PhotoLibraryExporting = PhotoLibraryExportService()
    ) {
        self.preferencesStore = preferencesStore
        self.transportFactory = transportFactory
        self.downloadStore = downloadStore
        self.photoLibraryExportService = photoLibraryExportService

        let config = preferencesStore.loadConnectionConfig()
        self.transportMode = config.transportMode
        self.hostInput = config.host
        self.portInput = String(config.port)
        self.autoExportToPhotoLibrary = config.autoExportToPhotoLibrary

        if let defaultHost = transportMode.defaultHost {
            self.hostInput = defaultHost
        }
        self.portInput = String(transportMode.defaultPort)
    }

    var canAttemptConnection: Bool {
        true
    }

    var canRefreshPhotos: Bool {
        activeSession?.capabilities.contains(.listAssets) == true && !isWorking
    }

    var canLoadMorePhotos: Bool {
        activeSession?.capabilities.contains(.listAssets) == true &&
        hasMorePhotos &&
        !isWorking
    }

    var canDownloadSelection: Bool {
        activeSession?.capabilities.contains(.downloadAssets) == true &&
        !selectedAssetIDs.isEmpty &&
        !isWorking
    }

    var selectedAssetsCount: Int {
        selectedAssetIDs.count
    }

    var connectionTargetDescription: String {
        switch transportMode {
        case .demo:
            return "使用内置样例数据"
        case .experimentalNikon:
            let host = transportMode.defaultHost ?? hostInput.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(host):\(transportMode.defaultPort)"
        }
    }

    var workingStatusTitle: String {
        guard workflowState == .downloading, let activeDownloadProgress else {
            return workflowState.title
        }

        return "下载 \(activeDownloadProgress.currentItemNumber)/\(activeDownloadProgress.totalItemCount) · \(activeDownloadProgress.percentageText)"
    }

    func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await refreshDownloads()
        appendLog("应用已初始化。")
    }

    func setTransportMode(_ newMode: CameraTransportMode) {
        transportMode = newMode
        if let defaultHost = newMode.defaultHost {
            hostInput = defaultHost
        }
        portInput = String(newMode.defaultPort)

        persistConfiguration()
        appendLog("传输模式已切换为\(newMode.title)。")
    }

    func setAutoExportToPhotoLibrary(_ isEnabled: Bool) {
        autoExportToPhotoLibrary = isEnabled
        persistConfiguration()
    }

    func connect() async {
        let transport = transportFactory.makeTransport(for: transportMode)

        do {
            let config = try validatedConfig()
            persistConfiguration()
            isWorking = true
            workflowState = .connecting
            photoAssets = []
            hasMorePhotos = false
            selectedAssetIDs = []
            activeDownloadProgress = nil
            activeSession = nil
            activeTransport = nil
            await thumbnailService.clear()

            appendLog("正在使用\(config.transportMode.title)建立连接...")
            AppLogger.transport.info("Connecting with mode \(config.transportMode.rawValue, privacy: .public)")
            let session = try await transport.connect(using: config)

            activeTransport = transport
            activeSession = session
            workflowState = .connected
            lastSummary = "已连接到\(session.cameraName)（\(session.connectedHost):\(session.port)）"
            appendLog(lastSummary)
            await appendTransportDiagnostics(from: transport)

            if session.capabilities.contains(.listAssets) {
                try await loadPhotos(resetTraversal: true)
            } else {
                appendLog("连接已验证，但当前传输模式暂不支持读取照片列表。")
            }
        } catch {
            await appendTransportDiagnostics(from: transport)
            handle(error)
        }

        isWorking = false
    }

    func disconnect() {
        let transport = activeTransport
        activeSession = nil
        activeTransport = nil
        photoAssets = []
        hasMorePhotos = false
        selectedAssetIDs = []
        activeDownloadProgress = nil
        workflowState = .waitingForWifi
        lastSummary = "当前会话已清除。"
        appendLog("当前会话已清除。")
        Task {
            await thumbnailService.clear()
        }

        if let transport {
            Task {
                await transport.disconnect()
            }
        }
    }

    func refreshPhotos() async {
        do {
            isWorking = true
            try await loadPhotos(resetTraversal: true)
        } catch {
            if let transport = activeTransport {
                await appendTransportDiagnostics(from: transport)
            }
            handle(error)
        }
        isWorking = false
    }

    func loadMorePhotos() async {
        do {
            isWorking = true
            try await loadPhotos(resetTraversal: false)
        } catch {
            if let transport = activeTransport {
                await appendTransportDiagnostics(from: transport)
            }
            handle(error)
        }
        isWorking = false
    }

    func toggleSelection(for asset: PhotoAsset) {
        if selectedAssetIDs.contains(asset.id) {
            selectedAssetIDs.remove(asset.id)
        } else {
            selectedAssetIDs.insert(asset.id)
        }
    }

    func selectAllAssets() {
        selectedAssetIDs = Set(photoAssets.map(\.id))
    }

    func clearSelection() {
        selectedAssetIDs.removeAll()
    }

    func downloadSelectedAssets() async {
        guard let session = activeSession, let transport = activeTransport else {
            handle(CameraAppError.notConnected)
            return
        }

        let targets = photoAssets.filter { selectedAssetIDs.contains($0.id) }
        guard !targets.isEmpty else { return }

        isWorking = true
        workflowState = .downloading
        activeDownloadProgress = nil
        appendLog("正在下载 \(targets.count) 个文件...")
        defer {
            activeDownloadProgress = nil
            isWorking = false
        }

        var exportFailures: [String] = []

        do {
            for (index, asset) in targets.enumerated() {
                let itemNumber = index + 1
                let totalItemCount = targets.count
                appendLog("开始下载 \(asset.fileName)（\(itemNumber)/\(totalItemCount)）")

                updateActiveDownloadProgress(
                    for: asset,
                    itemNumber: itemNumber,
                    totalItemCount: totalItemCount,
                    transportProgress: DownloadTransferProgress(
                        bytesTransferred: 0,
                        totalBytes: max(asset.byteSize, 0),
                        resumedCount: 0,
                        currentOffset: 0,
                        chunkSize: 0
                    )
                )

                let temporaryURL = try await transport.downloadAssetToTemporaryFile(
                    asset,
                    from: session
                ) { progress in
                    await MainActor.run {
                        self.updateActiveDownloadProgress(
                            for: asset,
                            itemNumber: itemNumber,
                            totalItemCount: totalItemCount,
                            transportProgress: progress
                        )
                    }
                }
                var didPersistDownload = false
                defer {
                    if !didPersistDownload {
                        try? FileManager.default.removeItem(at: temporaryURL)
                    }
                }

                let measuredSize = Self.fileSize(at: temporaryURL)
                let finalSize = measuredSize > 0
                    ? measuredSize
                    : max(activeDownloadProgress?.totalBytes ?? 0, max(asset.byteSize, 0))
                let fallbackChunkSize = max(activeDownloadProgress?.chunkSize ?? 0, finalSize)
                updateActiveDownloadProgress(
                    for: asset,
                    itemNumber: itemNumber,
                    totalItemCount: totalItemCount,
                    transportProgress: DownloadTransferProgress(
                        bytesTransferred: finalSize,
                        totalBytes: finalSize,
                        resumedCount: activeDownloadProgress?.resumedCount ?? 0,
                        currentOffset: finalSize,
                        chunkSize: fallbackChunkSize
                    ),
                    fallbackToAssetByteSize: false
                )

                var record = try await downloadStore.storeDownloadedFile(at: temporaryURL, from: asset)
                didPersistDownload = true
                appendLog("已将 \(record.fileName) 保存到应用存储。")

                if autoExportToPhotoLibrary {
                    do {
                        try await photoLibraryExportService.exportFile(at: record.savedURL)
                        record = try await downloadStore.markExported(recordID: record.id)
                        appendLog("已将 \(record.fileName) 导出到系统相册。")
                    } catch {
                        exportFailures.append("\(record.fileName): \(userFacingMessage(for: error))")
                    }
                }
            }

            workflowState = .connected
            lastSummary = "已下载 \(targets.count) 个文件。"
            selectedAssetIDs.removeAll()
            await refreshDownloads()

            if !exportFailures.isEmpty {
                alertContext = AlertContext(
                    title: "下载已完成，但有提示",
                    message: exportFailures.joined(separator: "\n")
                )
            }
        } catch {
            handle(error)
        }
    }

    func refreshDownloads() async {
        do {
            let directory = try await downloadStore.downloadsDirectoryURL()
            let records = try await downloadStore.listRecords()
            downloadDirectoryPath = directory.path
            downloads = records
        } catch {
            handle(error)
        }
    }

    func thumbnailData(for asset: PhotoAsset) async -> Data? {
        guard let session = activeSession, let transport = activeTransport else {
            return nil
        }

        return await thumbnailService.thumbnailData(
            for: asset,
            using: transport,
            session: session
        )
    }

    func previewData(for asset: PhotoAsset) async -> Data? {
        guard let session = activeSession, let transport = activeTransport else {
            return nil
        }

        return await thumbnailService.previewData(
            for: asset,
            using: transport,
            session: session
        )
    }

    private func validatedConfig() throws -> CameraConnectionConfig {
        let port = transportMode.defaultPort
        guard (1...65535).contains(port) else {
            throw CameraAppError.invalidPort
        }

        let host = transportMode.defaultHost ?? hostInput.trimmingCharacters(in: .whitespacesAndNewlines)

        let config = CameraConnectionConfig(
            host: host,
            port: port,
            transportMode: transportMode,
            autoExportToPhotoLibrary: autoExportToPhotoLibrary
        )

        if config.transportMode != .demo && config.normalizedHost.isEmpty {
            throw CameraAppError.missingHost
        }

        return config
    }

    static func mergePhotoAssetsPreservingCameraOrder(
        existing: [PhotoAsset],
        incoming: [PhotoAsset],
        resetTraversal: Bool
    ) -> [PhotoAsset] {
        let mergedAssets = resetTraversal ? incoming : (existing + incoming)
        var seenRemoteIdentifiers = Set<String>()
        return mergedAssets.filter { seenRemoteIdentifiers.insert($0.remoteIdentifier).inserted }
    }

    private func loadPhotos(resetTraversal: Bool) async throws {
        guard let session = activeSession, let transport = activeTransport else {
            throw CameraAppError.notConnected
        }

        if resetTraversal {
            await thumbnailService.clear()
        }

        workflowState = .loadingPhotos
        appendLog(resetTraversal ? "正在读取首批照片..." : "正在继续读取照片...")

        let page = try await transport.fetchAssetsPage(
            for: session,
            resetTraversal: resetTraversal,
            limit: photoPageSize
        )
        await appendTransportDiagnostics(from: transport)

        photoAssets = Self.mergePhotoAssetsPreservingCameraOrder(
            existing: photoAssets,
            incoming: page.assets,
            resetTraversal: resetTraversal
        )
        hasMorePhotos = page.hasMore

        if resetTraversal {
            selectedAssetIDs.removeAll()
        }

        workflowState = .connected
        if resetTraversal {
            lastSummary = page.hasMore
                ? "已读取首批 \(photoAssets.count) 张照片，可继续读取更多。"
                : "已读取 \(photoAssets.count) 张照片。"
        } else if page.assets.isEmpty, !page.hasMore {
            lastSummary = "已经读完，累计 \(photoAssets.count) 张照片。"
        } else {
            lastSummary = page.hasMore
                ? "又读取了 \(page.assets.count) 张，当前已加载 \(photoAssets.count) 张。"
                : "又读取了 \(page.assets.count) 张，已全部读取，共 \(photoAssets.count) 张。"
        }
        appendLog(lastSummary)
    }

    private func persistConfiguration() {
        let host = transportMode.defaultHost ?? hostInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let config = CameraConnectionConfig(
            host: host,
            port: transportMode.defaultPort,
            transportMode: transportMode,
            autoExportToPhotoLibrary: autoExportToPhotoLibrary
        )

        preferencesStore.saveConnectionConfig(config)
    }

    private func handle(_ error: Error) {
        activeDownloadProgress = nil
        workflowState = .error
        let title = "出现问题"
        let message = userFacingMessage(for: error)
        alertContext = AlertContext(title: title, message: message)
        lastSummary = message
        appendLog(message)
        AppLogger.app.error("\(message, privacy: .public)")
    }

    private func userFacingMessage(for error: Error) -> String {
        if let localError = error as? LocalizedError {
            return [localError.errorDescription, localError.recoverySuggestion]
                .compactMap { $0 }
                .joined(separator: "\n")
        }

        return error.localizedDescription
    }

    private func appendLog(_ message: String) {
        let entry = LogEntry(timestamp: Date(), message: message)
        activityLog.insert(entry, at: 0)

        if activityLog.count > 30 {
            activityLog = Array(activityLog.prefix(30))
        }
    }

    private func appendTransportDiagnostics(from transport: any CameraTransport) async {
        let messages = await transport.consumeDiagnostics()
        for message in messages where !message.isEmpty {
            appendLog("诊断: \(message)")
        }
    }

    private func updateActiveDownloadProgress(
        for asset: PhotoAsset,
        itemNumber: Int,
        totalItemCount: Int,
        transportProgress: DownloadTransferProgress,
        fallbackToAssetByteSize: Bool = true
    ) {
        let knownTotal = fallbackToAssetByteSize ? max(asset.byteSize, 0) : 0
        let resolvedTotal = max(max(transportProgress.totalBytes, transportProgress.bytesTransferred), knownTotal)
        let resolvedTransferred = min(max(transportProgress.bytesTransferred, 0), resolvedTotal)
        let resolvedOffset = min(max(transportProgress.currentOffset, resolvedTransferred), resolvedTotal)

        activeDownloadProgress = ActiveDownloadProgress(
            fileName: asset.fileName,
            currentItemNumber: itemNumber,
            totalItemCount: totalItemCount,
            bytesTransferred: resolvedTransferred,
            totalBytes: resolvedTotal,
            resumedCount: max(transportProgress.resumedCount, 0),
            currentOffset: resolvedOffset,
            chunkSize: max(transportProgress.chunkSize, 0)
        )
    }

    private static func fileSize(at url: URL) -> Int64 {
        ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.int64Value ?? 0
    }
}
