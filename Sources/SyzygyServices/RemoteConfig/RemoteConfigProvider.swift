import Foundation
import SyzygyFoundation

// MARK: - Protocol

/// Defines the contract for fetching remote configuration values.
public protocol RemoteConfigProvider: Sendable {
    /// Returns the string value for the given config key, or nil if not set.
    func string(forKey key: String) -> String?
    /// Returns the boolean value for the given config key, or nil if not set.
    func bool(forKey key: String) -> Bool?
    /// Sets a value for the given key (used in testing and in-memory implementations).
    func setValue(_ value: Any?, forKey key: String)
}

// MARK: - In-Memory Implementation

/// A `RemoteConfigProvider` backed by an in-memory dictionary.
public final class InMemoryRemoteConfigProvider: RemoteConfigProvider {
    nonisolated(unsafe) private var store: [String: Any] = [:]

    /// Initialises the provider with an optional initial store.
    public init(initialValues: [String: Any] = [:]) {
        self.store = initialValues
    }

    public func string(forKey key: String) -> String? {
        store[key] as? String
    }

    public func bool(forKey key: String) -> Bool? {
        store[key] as? Bool
    }

    public func setValue(_ value: Any?, forKey key: String) {
        store[key] = value
    }
}
