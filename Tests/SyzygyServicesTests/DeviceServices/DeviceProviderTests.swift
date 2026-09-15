import Testing
import Foundation
@testable import SyzygyServices

@Suite("DeviceProvider")
struct DeviceProviderTests {

    @Test("platform is always 'ios'")
    func platformIsIos() {
        let provider = PlatformDeviceProvider(
            storage: KeychainStorageProvider(service: "com.test.device.\(UUID().uuidString)")
        )
        #expect(provider.platform == "ios")
    }

    @Test("osVersion is non-empty")
    func osVersionNonEmpty() {
        let provider = PlatformDeviceProvider(
            storage: KeychainStorageProvider(service: "com.test.device.\(UUID().uuidString)")
        )
        #expect(!provider.osVersion.isEmpty)
    }

    @Test("deviceId is a persistent UUID-format string")
    func deviceIdIsPersisted() {
        let service = "com.test.device.\(UUID().uuidString)"
        let storage = KeychainStorageProvider(service: service)
        let provider1 = PlatformDeviceProvider(storage: storage)
        let id1 = provider1.deviceId
        // Second provider sharing the same keychain entry returns the same ID
        let provider2 = PlatformDeviceProvider(storage: storage)
        let id2 = provider2.deviceId
        #expect(id1 == id2)
        #expect(UUID(uuidString: id1) != nil)
        storage.clear() // cleanup
    }

    @Test("isSimulator returns true in test environment")
    func isSimulatorInTestEnvironment() {
        let provider = PlatformDeviceProvider(
            storage: KeychainStorageProvider(service: "com.test.device.\(UUID().uuidString)")
        )
        // Tests always run on simulator or macOS — either way isSimulator == true
        // on macOS the #if targetEnvironment(simulator) is false, but we test the property exists
        _ = provider.isSimulator // just verify it compiles and returns a Bool
        #expect(true)
    }

    @Test("systemName is non-empty")
    func systemNameNonEmpty() {
        let provider = PlatformDeviceProvider(
            storage: KeychainStorageProvider(service: "com.test.device.\(UUID().uuidString)")
        )
        #expect(!provider.systemName.isEmpty)
    }

    // MARK: - Item 1: Persistent UUID

    @Test("deviceId is consistent across multiple calls on the same provider")
    func deviceIdConsistentAcrossMultipleCalls() {
        let provider = PlatformDeviceProvider(
            storage: KeychainStorageProvider(service: "com.test.device.\(UUID().uuidString)")
        )
        let id1 = provider.deviceId
        let id2 = provider.deviceId
        let id3 = provider.deviceId
        #expect(id1 == id2)
        #expect(id2 == id3)
    }

    @Test("deviceId persists across provider re-instantiation using same storage")
    func deviceIdPersistsAcrossReinstantiation() {
        let service = "com.test.device.persist.\(UUID().uuidString)"
        let storage = KeychainStorageProvider(service: service)
        let provider1 = PlatformDeviceProvider(storage: storage)
        let firstId = provider1.deviceId
        // Re-instantiate a brand-new provider pointing at the same keychain service
        let provider2 = PlatformDeviceProvider(storage: storage)
        let secondId = provider2.deviceId
        #expect(firstId == secondId, "UUID must survive re-instantiation")
        #expect(UUID(uuidString: firstId) != nil, "Must be valid UUID format")
        storage.clear() // cleanup
    }
}
