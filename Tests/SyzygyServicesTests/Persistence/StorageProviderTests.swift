import Testing
import Foundation
@testable import SyzygyServices
import SyzygyFoundation

@Suite("StorageProvider")
struct StorageProviderTests {

    // MARK: - UserDefaults

    @Test("UserDefaults set/get round-trips a Codable value")
    func userDefaultsRoundTrip() {
        let suiteName = "test.storage.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let provider = UserDefaultsStorageProvider(defaults: defaults)
        let key = StorageKey<String>(identifier: "greeting")
        provider.set("hello", for: key)
        #expect(provider.get(key) == "hello")
    }

    @Test("UserDefaults missing key returns nil")
    func userDefaultsMissingKeyReturnsNil() {
        let suiteName = "test.storage.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let provider = UserDefaultsStorageProvider(defaults: defaults)
        let key = StorageKey<Int>(identifier: "missing")
        #expect(provider.get(key) == nil)
    }

    @Test("UserDefaults missing key returns default value when present")
    func userDefaultsMissingKeyReturnsDefault() {
        let suiteName = "test.storage.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let provider = UserDefaultsStorageProvider(defaults: defaults)
        let key = StorageKey<Int>(identifier: "count", defaultValue: 42)
        #expect(provider.get(key) == 42)
    }

    @Test("UserDefaults remove clears value")
    func userDefaultsRemove() {
        let suiteName = "test.storage.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let provider = UserDefaultsStorageProvider(defaults: defaults)
        let key = StorageKey<Bool>(identifier: "flag")
        provider.set(true, for: key)
        provider.remove(key)
        #expect(provider.get(key) == nil)
    }

    // MARK: - Keychain

    @Test("Keychain set/get round-trips a Codable value")
    func keychainRoundTrip() {
        let provider = KeychainStorageProvider(service: "com.test.keychain.\(UUID().uuidString)")
        let key = StorageKey<String>(identifier: "secret")
        provider.set("s3cr3t", for: key)
        #expect(provider.get(key) == "s3cr3t")
        provider.remove(key) // cleanup
    }

    @Test("Keychain missing key returns nil")
    func keychainMissingKeyReturnsNil() {
        let provider = KeychainStorageProvider(service: "com.test.keychain.\(UUID().uuidString)")
        let key = StorageKey<String>(identifier: "nonexistent")
        #expect(provider.get(key) == nil)
    }

    @Test("Keychain clear removes all entries for service")
    func keychainClear() {
        let service = "com.test.keychain.\(UUID().uuidString)"
        let provider = KeychainStorageProvider(service: service)
        let key1 = StorageKey<String>(identifier: "k1")
        let key2 = StorageKey<Int>(identifier: "k2")
        provider.set("v1", for: key1)
        provider.set(99, for: key2)
        provider.clear()
        #expect(provider.get(key1) == nil)
        #expect(provider.get(key2) == nil)
    }

    // MARK: - Item 2: Type-safe getOrThrow

    @Test("UserDefaults getOrThrow returns value when types match")
    func userDefaultsGetOrThrowSucceedsOnCorrectType() throws {
        let suiteName = "test.storage.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let provider = UserDefaultsStorageProvider(defaults: defaults)
        let key = StorageKey<String>(identifier: "typed_key")
        provider.set("hello", for: key)
        let result = try provider.getOrThrow(key)
        #expect(result == "hello")
    }

    @Test("UserDefaults getOrThrow throws StorageServiceError on type mismatch")
    func userDefaultsGetOrThrowThrowsOnTypeMismatch() {
        let suiteName = "test.storage.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let provider = UserDefaultsStorageProvider(defaults: defaults)
        // Store a String under key "mismatch"
        let stringKey = StorageKey<String>(identifier: "mismatch")
        provider.set("not_an_int", for: stringKey)
        // Try to read as Int — should throw
        let intKey = StorageKey<Int>(identifier: "mismatch")
        do {
            _ = try provider.getOrThrow(intKey)
            Issue.record("Expected StorageServiceError to be thrown")
        } catch let error as StorageServiceError {
            #expect(error.message.contains("mismatch"))
            #expect(error.code == .decodingFailed)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Keychain getOrThrow returns value when types match")
    func keychainGetOrThrowSucceedsOnCorrectType() throws {
        let provider = KeychainStorageProvider(service: "com.test.keychain.\(UUID().uuidString)")
        let key = StorageKey<String>(identifier: "typed_secret")
        provider.set("s3cr3t", for: key)
        let result = try provider.getOrThrow(key)
        #expect(result == "s3cr3t")
        provider.remove(key)
    }

    @Test("Keychain getOrThrow throws StorageServiceError on type mismatch")
    func keychainGetOrThrowThrowsOnTypeMismatch() {
        let service = "com.test.keychain.\(UUID().uuidString)"
        let provider = KeychainStorageProvider(service: service)
        // Store a String under identifier "km"
        let stringKey = StorageKey<String>(identifier: "km")
        provider.set("wrong_type", for: stringKey)
        // Try to decode as Bool — should throw
        let boolKey = StorageKey<Bool>(identifier: "km")
        do {
            _ = try provider.getOrThrow(boolKey)
            Issue.record("Expected StorageServiceError to be thrown")
        } catch let error as StorageServiceError {
            #expect(error.message.contains("km"))
            #expect(error.code == .decodingFailed)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
        provider.clear()
    }
}
