import XCTest
@testable import NikonConnectIOS

final class MockNikonTransportTests: XCTestCase {
    actor ProgressRecorder {
        private var values: [DownloadTransferProgress] = []

        func append(_ progress: DownloadTransferProgress) {
            values.append(progress)
        }

        func snapshot() -> [DownloadTransferProgress] {
            values
        }
    }

    func testMockTransportReturnsAssetsAndData() async throws {
        let transport = MockNikonTransport()
        let config = CameraConnectionConfig.default
        let session = try await transport.connect(using: config)
        let firstPage = try await transport.fetchAssetsPage(
            for: session,
            resetTraversal: true,
            limit: 2
        )

        XCTAssertEqual(firstPage.assets.count, 2)
        XCTAssertTrue(firstPage.hasMore)

        let secondPage = try await transport.fetchAssetsPage(
            for: session,
            resetTraversal: false,
            limit: 2
        )

        XCTAssertEqual(secondPage.assets.count, 1)
        XCTAssertFalse(secondPage.hasMore)

        let data = try await transport.downloadAsset(firstPage.assets[0], from: session)
        XCTAssertFalse(data.isEmpty)

        let progressRecorder = ProgressRecorder()
        let temporaryURL = try await transport.downloadAssetToTemporaryFile(
            firstPage.assets[0],
            from: session
        ) { progress in
            await progressRecorder.append(progress)
        }
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: temporaryURL.path))
        let streamedData = try Data(contentsOf: temporaryURL)
        XCTAssertEqual(streamedData, data)

        let progressUpdates = await progressRecorder.snapshot()
        XCTAssertGreaterThanOrEqual(progressUpdates.count, 2)
        XCTAssertEqual(progressUpdates.first?.bytesTransferred, 0)
        XCTAssertEqual(progressUpdates.first?.currentOffset, 0)
        XCTAssertEqual(progressUpdates.last?.bytesTransferred, progressUpdates.last?.totalBytes)
    }
}
