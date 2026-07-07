import Foundation
import SwiftUI

@MainActor
final class ConnectionViewModel: ObservableObject {
    @Published var hostInput: String
    @Published var portInput: String
    @Published var transportMode: CameraTransportMode
    @Published var autoExportToPhotoLibrary: Bool
    @Published var workflowState: CameraWorkflowState = .waitingForWifi
    @Published var activeSession: CameraSession?
    @Published var lastSummary = "先在系统设置里连接 Nikon 相机的 Wi‑Fi，然后回到这里开始。"
    @Published var isWorking = false

    private let preferencesStore: any AppPreferencesStoring
    private let transportFactory: any CameraTransportFactoryProtocol
    private let thumbnailService: any AssetThumbnailServing
    private let sessionCoordinator: CameraSessionCoordinator
    private let shell: AppShellViewModel
    private var didBootstrap = false

    init(
        preferencesStore: any AppPreferencesStoring,
        transportFactory: any CameraTransportFactoryProtocol,
        thumbnailService: any AssetThumbnailServing,
        sessionCoordinator: CameraSessionCoordinator,
        shell: AppShellViewModel
    ) {
        self.preferencesStore = preferencesStore
        self.transportFactory = transportFactory
        self.thumbnailService = thumbnailService
        self.sessionCoordinator = sessionCoordinator
        self.shell = shell

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
        shell.appendLog("应用已初始化。")
    }

    func setTransportMode(_ newMode: CameraTransportMode) {
        transportMode = newMode
        if let defaultHost = newMode.defaultHost {
            hostInput = defaultHost
        }
        portInput = String(newMode.defaultPort)

        persistConfiguration()
        shell.appendLog("传输模式已切换为\(newMode.title)。")
    }

    func setAutoExportToPhotoLibrary(_ isEnabled: Bool) {
        autoExportToPhotoLibrary = isEnabled
        persistConfiguration()
    }

    @discardableResult
    func connect() async -> Bool {
        let transport = transportFactory.makeTransport(for: transportMode)

        do {
            let config = try validatedConfig()
            persistConfiguration()
            isWorking = true
            shell.setGlobalActivityTitle(CameraWorkflowState.connecting.title)
            workflowState = .connecting
            activeSession = nil
            _ = sessionCoordinator.clearSession()
            await thumbnailService.clear()

            shell.appendLog("正在使用\(config.transportMode.title)建立连接...")
            AppLogger.transport.info("Connecting with mode \(config.transportMode.rawValue, privacy: .public)")
            let session = try await transport.connect(using: config)

            sessionCoordinator.setActiveSession(session, transport: transport)
            activeSession = session
            workflowState = .connected
            lastSummary = "已连接到\(session.cameraName)（\(session.connectedHost):\(session.port)）"
            shell.appendLog(lastSummary)
            await appendTransportDiagnostics(from: transport)
            isWorking = false
            shell.setGlobalActivityTitle(nil)
            return true
        } catch {
            await appendTransportDiagnostics(from: transport)
            handle(error)
            isWorking = false
            shell.setGlobalActivityTitle(nil)
            return false
        }
    }

    func disconnect() {
        let transport = sessionCoordinator.clearSession()
        activeSession = nil
        workflowState = .waitingForWifi
        lastSummary = "当前会话已清除。"
        shell.appendLog("当前会话已清除。")
        Task {
            await thumbnailService.clear()
        }

        if let transport {
            Task {
                await transport.disconnect()
            }
        }
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
        lastSummary = shell.handle(error)
    }

    private func appendTransportDiagnostics(from transport: any CameraTransport) async {
        let messages = await transport.consumeDiagnostics()
        for message in messages where !message.isEmpty {
            shell.appendLog("诊断: \(message)")
        }
    }
}
