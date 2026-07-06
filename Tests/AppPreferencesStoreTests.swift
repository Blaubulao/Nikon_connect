import XCTest
@testable import NikonConnectIOS

final class AppPreferencesStoreTests: XCTestCase {
    func testSaveAndLoadConnectionConfig() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = AppPreferencesStore(userDefaults: defaults)

        let config = CameraConnectionConfig(
            host: "192.168.1.1",
            port: 15740,
            transportMode: .experimentalNikon,
            autoExportToPhotoLibrary: true
        )

        store.saveConnectionConfig(config)
        let loaded = store.loadConnectionConfig()

        XCTAssertEqual(loaded, config)
    }
}
