import Foundation

actor PTPIPSession {
    static let defaultChunkSize = 1_048_576
    static let maxChunkRetryCount = 5
    static let connectionRetryCount = 5
    static let connectionRetryDelayNanoseconds: UInt64 = 300_000_000
    let host: String
    let port: UInt16
    let commandConnection: PTPIPTCPConnection
    let eventConnection: PTPIPTCPConnection
    let initiatorGUID: Data

    var responderFriendlyName = "Nikon 相机"
    var connectionNumber: UInt32?
    var nextTransactionID: UInt32 = 1
    var isOpen = false
    var diagnostics: [String] = []
    var assetTraversalState: AssetTraversalState?
    var thumbnailOperationSupport: ThumbnailOperationSupport = .unknown
    var deviceInfo: PTPIPDeviceInfo?
    var downloadStrategy: DownloadStrategy = .fullObject
    var eventMonitorTask: Task<Void, Never>?
    var probeTask: Task<Void, Never>?
    var latestSentProbeSequence: UInt64 = 0
    var latestAcknowledgedProbeSequence: UInt64 = 0
    var isCommandChannelBusy = false
    var commandChannelWaiters: [CheckedContinuation<Void, Never>] = []

    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
        self.commandConnection = PTPIPTCPConnection(host: host, port: port)
        self.eventConnection = PTPIPTCPConnection(host: host, port: port)
        self.initiatorGUID = Self.loadOrCreateInitiatorGUID()
    }

    func establishConnection() async throws -> PTPIPDeviceInfo {
        recordDiagnostic("准备连接 \(host):\(port) ...")
        return try await openSessionSequence(reason: "初始连接")
    }

    func close() async {
        await closeSessionTransport()
    }

    func fetchAssetsPage(limit: Int, resetTraversal: Bool) async throws -> PhotoAssetPage {
        try await loadAssetsPage(limit: limit, resetTraversal: resetTraversal)
    }

    func downloadAsset(handle: UInt32) async throws -> Data {
        try await downloadAssetPayload(handle: handle)
    }

    func downloadAssetToTemporaryFile(handle: UInt32, suggestedFileName: String) async throws -> URL {
        try await downloadAssetToTemporaryFile(
            handle: handle,
            suggestedFileName: suggestedFileName,
            onProgress: nil
        )
    }

    func downloadAssetToTemporaryFile(
        handle: UInt32,
        suggestedFileName: String,
        onProgress: (@Sendable (DownloadTransferProgress) async -> Void)?
    ) async throws -> URL {
        try await downloadAssetToTemporaryFilePayload(
            handle: handle,
            suggestedFileName: suggestedFileName,
            onProgress: onProgress
        )
    }

    func downloadThumbnail(handle: UInt32) async throws -> Data? {
        try await loadThumbnailData(handle: handle)
    }

    func consumeDiagnostics() -> [String] {
        let current = diagnostics
        diagnostics.removeAll()
        return current
    }
}

extension PTPIPSession {
    enum ThumbnailOperationSupport {
        case unknown
        case supported
        case unsupported
    }

    enum DownloadStrategy {
        case fullObject
        case partialObject(chunkSize: Int)
    }

    enum ObjectClassification {
        case asset(PhotoAsset)
        case directory
        case unsupported((UInt32, UInt16, String))
    }

    struct AssetTraversalState {
        var queue: [UInt32]
        var nextIndex: Int
        var seenHandles: Set<UInt32>
        var loadedAssetHandles: Set<UInt32>
        var exploredDirectoryHandles: Set<UInt32>
        var unsupportedHandles: Set<UInt32>
        var handleKindHints: [UInt32: PhotoAssetKind]
        var handleCaptureDateHints: [UInt32: Date]
    }

    struct HandleDiscovery {
        var handles: [UInt32]
        var kindHints: [UInt32: PhotoAssetKind]
        var captureDateHints: [UInt32: Date]
    }

    struct NikonObjectMetaData: Sendable {
        let handle: UInt32
        let kind: PhotoAssetKind?
        let captureDate: Date?
    }

    struct BackgroundTaskState: Sendable {
        let hasEventMonitorTask: Bool
        let hasProbeTask: Bool
    }
}
