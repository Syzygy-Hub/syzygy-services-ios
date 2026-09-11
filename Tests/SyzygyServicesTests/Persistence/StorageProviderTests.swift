import Testing
import Foundation
@testable import SyzygyServices

@Suite("StorageProvider")
struct StorageProviderTests {
    @Test("UserDefaultsStorageProvider round-trips a value")
    func roundTripsValue() {
        let provider = UserDefaultsStorageProvider(defaults: UserDefaults(suiteName: "test.storage")!)
        provider.set("hello", forKey: "key")
        #expect(provider.value(forKey: "key") as? String == "hello")
        provider.removeValue(forKey: "key")
        #expect(provider.value(forKey: "key") == nil)
    }
}
