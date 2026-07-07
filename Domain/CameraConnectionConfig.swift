import Foundation

struct CameraConnectionConfig: Codable, Equatable, Sendable {
    var host: String
    var port: Int
    var transportMode: CameraTransportMode
    var autoExportToPhotoLibrary: Bool

    static let `default` = CameraConnectionConfig(
        host: CameraTransportMode.experimentalNikon.defaultHost ?? "",
        port: CameraTransportMode.experimentalNikon.defaultPort,
        transportMode: .experimentalNikon,
        autoExportToPhotoLibrary: false
    )

    var normalizedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
