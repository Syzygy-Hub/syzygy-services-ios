import Foundation
import SyzygyFoundation

// MARK: - Protocol

/// Defines the contract for key-value persistence storage.
public protocol StorageProvider: Sendable {
    /// Stores a value for the given key.
    func set(_ value: Any?, forKey key: String)
    /// Retrieves the value for the given key.
    func value(forKey key: String) -> Any?
    /// Removes the value for the given key.
    func removeValue(forKey key: String)
}

// MARK: - UserDefaults Implementation

/// A `StorageProvider` backed by `UserDefaults`.
public final class UserDefaultsStorageProvider: StorageProvider {
    nonisolated(unsafe) private let defaults: UserDefaults

    /// Initialises the provider with the given `UserDefaults` suite.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func set(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public func value(forKey key: String) -> Any? {
        defaults.object(forKey: key)
    }

    public func removeValue(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}
