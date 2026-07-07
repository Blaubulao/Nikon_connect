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

    func testStoreDownloadedFileMovesTemporaryFile() async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = DownloadStore(rootDirectory: rootURL)
        let temporaryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        let originalData = Data([9, 8, 7, 6, 5])
        try originalData.write(to: temporaryURL, options: .atomic)

        let asset = PhotoAsset(
            remoteIdentifier: "asset-2",
            fileName: "streamed.jpg",
            kind: .jpeg,
            byteSize: Int64(originalData.count),
            captureDate: Date()
        )

        let record = try await store.storeDownloadedFile(at: temporaryURL, from: asset)

        XCTAssertFalse(fileManager.fileExists(atPath: temporaryURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: record.savedURL.path))
        XCTAssertEqual(record.byteSize, Int64(originalData.count))
    }
}
