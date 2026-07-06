import Foundation

protocol CameraTransport: Sendable {
    func connect(using config: CameraConnectionConfig) async throws -> CameraSession
    func fetchAssetsPage(
        for session: CameraSession,
        resetTraversal: Bool,
        limit: Int
    ) async throws -> PhotoAssetPage
    func downloadThumbnail(_ asset: PhotoAsset, from session: CameraSession) async throws -> Data?
    func downloadAsset(_ asset: PhotoAsset, from session: CameraSession) async throws -> Data
    func consumeDiagnostics() async -> [String]
    func disconnect() async
}

extension CameraTransport {
    func downloadThumbnail(_ asset: PhotoAsset, from session: CameraSession) async throws -> Data? {
        nil
    }
}
