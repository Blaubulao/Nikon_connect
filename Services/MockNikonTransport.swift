import Foundation

actor MockNikonTransport: CameraTransport {
    private var nextAssetIndex = 0

    private let sampleAssets: [PhotoAsset] = {
        let now = Date()
        return [
            PhotoAsset(
                remoteIdentifier: "demo-1",
                fileName: "Z5_DEMO_0001.png",
                kind: .png,
                byteSize: 68_412,
                captureDate: now.addingTimeInterval(-18_000)
            ),
            PhotoAsset(
                remoteIdentifier: "demo-2",
                fileName: "Z5_DEMO_0002.png",
                kind: .png,
                byteSize: 71_004,
                captureDate: now.addingTimeInterval(-12_000)
            ),
            PhotoAsset(
                remoteIdentifier: "demo-3",
                fileName: "Z5_DEMO_0003.png",
                kind: .png,
                byteSize: 69_872,
                captureDate: now.addingTimeInterval(-5_400)
            )
        ]
    }()

    func connect(using config: CameraConnectionConfig) async throws -> CameraSession {
        nextAssetIndex = 0
        try await Task.sleep(nanoseconds: 350_000_000)

        return CameraSession(
            cameraName: "Nikon Z5 演示模式",
            connectedHost: config.normalizedHost.isEmpty ? "demo.local" : config.normalizedHost,
            port: config.port,
            capabilities: [.connectionProbe, .listAssets, .downloadAssets]
        )
    }

    func fetchAssetsPage(
        for session: CameraSession,
        resetTraversal: Bool,
        limit: Int
    ) async throws -> PhotoAssetPage {
        if resetTraversal {
            nextAssetIndex = 0
        }

        try await Task.sleep(nanoseconds: 250_000_000)

        let pageSize = max(1, limit)
        let startIndex = min(nextAssetIndex, sampleAssets.count)
        let endIndex = min(startIndex + pageSize, sampleAssets.count)
        let assets = Array(sampleAssets[startIndex ..< endIndex])
        nextAssetIndex = endIndex

        return PhotoAssetPage(
            assets: assets,
            hasMore: nextAssetIndex < sampleAssets.count
        )
    }

    func downloadAsset(_ asset: PhotoAsset, from session: CameraSession) async throws -> Data {
        try await Task.sleep(nanoseconds: 150_000_000)
        guard let data = Data(base64Encoded: Self.tinyPNGBase64) else {
            throw CameraAppError.fileSystemFailure("无法生成样例图片数据。")
        }

        return data
    }

    func consumeDiagnostics() async -> [String] {
        []
    }

    func disconnect() async {
        nextAssetIndex = 0
    }

    private static let tinyPNGBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg=="
}
