import XCTest
@testable import NikonConnectIOS

final class MockNikonTransportTests: XCTestCase {
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
    }
}
