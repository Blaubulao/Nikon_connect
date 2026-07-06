import Foundation
import SwiftUI

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
        appendLog("正在下载 \(targets.count) 个文件...")

        var exportFailures: [String] = []

        do {
            for asset in targets {
                let data = try await transport.downloadAsset(asset, from: session)
                var record = try await downloadStore.store(data: data, from: asset)
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

        isWorking = false
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

        var mergedAssets = resetTraversal ? page.assets : (photoAssets + page.assets)
        var seenRemoteIdentifiers = Set<String>()
        mergedAssets = mergedAssets.filter { seenRemoteIdentifiers.insert($0.remoteIdentifier).inserted }

        photoAssets = mergedAssets.sorted { $0.captureDate > $1.captureDate }
        hasMorePhotos = page.hasMore

        if resetTraversal {
            selectedAssetIDs = Set(photoAssets.prefix(2).map(\.id))
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
}
