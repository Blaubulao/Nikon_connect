import XCTest
@testable import NikonConnectIOS

final class DownloadStoreTests: XCTestCase {
    func testStoreAndListRecords() async throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = DownloadStore(rootDirectory: rootURL)

        let asset = PhotoAsset(
            remoteIdentifier: "asset-1",
            fileName: "sample.png",
            kind: .png,
            byteSize: 10,
            captureDate: Date()
        )

        _ = try await store.store(data: Data([0, 1, 2, 3]), from: asset)
        let records = try await store.listRecords()

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.fileName, "sample.png")
    }
}
