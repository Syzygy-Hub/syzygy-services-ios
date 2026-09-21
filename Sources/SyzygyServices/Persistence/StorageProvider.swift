import Foundation
import Security
import SyzygyFoundation

// MARK: - StorageServiceError

/// A storage-layer error conforming to `SyzygyError`.
public struct StorageServiceError: SyzygyError {
    public let code: SyzygyErrorCode
    public let message: String
    public let severity: SyzygyErrorSeverity
    public let underlyingError: (any Error)?

    public init(
        code: SyzygyErrorCode = .decodingFailed,
        message: String,
        severity: SyzygyErrorSeverity = .error,
        underlyingError: (any Error)? = nil
    ) {
        self.code = code
        self.message = message
        self.severity = severity
        self.underlyingError = underlyingError
    }
}

// MARK: - UserDefaultsStorageProvider

/// A `SyzygyFoundation.StorageProvider` backed by `UserDefaults` for non-sensitive data.
public final class UserDefaultsStorageProvider: SyzygyFoundation.StorageProvider, @unchecked Sendable {

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    /// Initialises the provider with a `UserDefaults` suite.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func get<T: Codable & Sendable>(_ key: StorageKey<T>) -> T? {
        lock.withLock {
            guard let data = defaults.data(forKey: key.identifier) else {
                return key.defaultValue
            }
            return try? decoder.decode(T.self, from: data)
        }
    }

    /// Retrieves the value for the given key, throwing a descriptive `StorageServiceError`
    /// if data exists but cannot be decoded as `T`.
    public func getOrThrow<T: Codable & Sendable>(_ key: StorageKey<T>) throws -> T? {
        try lock.withLock {
            guard let data = defaults.data(forKey: key.identifier) else {
                return key.defaultValue
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                let storedType = Self.jsonTypeName(from: data)
                let msg = "Type mismatch for key '\(key.identifier)': " +
                    "stored type is \(storedType), requested type is \(T.self)"
                throw StorageServiceError(message: msg, underlyingError: error)
            }
        }
    }

    private static func jsonTypeName(from data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { return "unknown" }
        return String(describing: Swift.type(of: obj))
    }

    public func set<T: Codable & Sendable>(_ value: T, for key: StorageKey<T>) {
        lock.withLock {
            let data = try? encoder.encode(value)
            defaults.set(data, forKey: key.identifier)
        }
    }

    public func remove<T: Sendable>(_ key: StorageKey<T>) {
        lock.withLock {
            defaults.removeObject(forKey: key.identifier)
        }
    }

    public func clear() {
        lock.withLock {
            guard let domain = defaults.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") else {
                defaults.dictionaryRepresentation().keys.forEach { defaults.removeObject(forKey: $0) }
                return
            }
            domain.keys.forEach { defaults.removeObject(forKey: $0) }
        }
    }
}

// MARK: - KeychainStorageProvider

/// A `SyzygyFoundation.StorageProvider` backed by the system Keychain for sensitive data.
public final class KeychainStorageProvider: SyzygyFoundation.StorageProvider, @unchecked Sendable {

    private let service: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    /// Initialises the provider.
    /// - Parameter service: The Keychain service name used to namespace entries.
    public init(service: String = Bundle.main.bundleIdentifier ?? "com.syzygy.services") {
        self.service = service
    }

    public func get<T: Codable & Sendable>(_ key: StorageKey<T>) -> T? {
        lock.withLock {
            guard let data = keychainData(for: key.identifier) else { return key.defaultValue }
            return try? decoder.decode(T.self, from: data)
        }
    }

    /// Retrieves the value for the given key, throwing a descriptive `StorageServiceError`
    /// if data exists but cannot be decoded as `T`.
    public func getOrThrow<T: Codable & Sendable>(_ key: StorageKey<T>) throws -> T? {
        try lock.withLock {
            guard let data = keychainData(for: key.identifier) else { return key.defaultValue }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                let storedType = Self.jsonTypeName(from: data)
                let msg = "Type mismatch for key '\(key.identifier)': " +
                    "stored type is \(storedType), requested type is \(T.self)"
                throw StorageServiceError(message: msg, underlyingError: error)
            }
        }
    }

    private func keychainData(for identifier: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    private static func jsonTypeName(from data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { return "unknown" }
        return String(describing: Swift.type(of: obj))
    }

    public func set<T: Codable & Sendable>(_ value: T, for key: StorageKey<T>) {
        lock.withLock {
            guard let data = try? encoder.encode(value) else { return }
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key.identifier
            ]
            let attributes: [String: Any] = [kSecValueData as String: data]
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if status == errSecItemNotFound {
                var addQuery = query
                addQuery[kSecValueData as String] = data
                SecItemAdd(addQuery as CFDictionary, nil)
            }
        }
    }

    public func remove<T: Sendable>(_ key: StorageKey<T>) {
        lock.withLock {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key.identifier
            ]
            SecItemDelete(query as CFDictionary)
        }
    }

    public func clear() {
        lock.withLock {
            // Enumerate all items for this service and delete individually for reliability.
            let findQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecReturnAttributes as String: true,
                kSecMatchLimit as String: kSecMatchLimitAll
            ]
            var result: AnyObject?
            guard SecItemCopyMatching(findQuery as CFDictionary, &result) == errSecSuccess,
                  let items = result as? [[String: Any]] else { return }
            for item in items {
                guard let account = item[kSecAttrAccount as String] as? String else { continue }
                let deleteQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account
                ]
                SecItemDelete(deleteQuery as CFDictionary)
            }
        }
    }
}
