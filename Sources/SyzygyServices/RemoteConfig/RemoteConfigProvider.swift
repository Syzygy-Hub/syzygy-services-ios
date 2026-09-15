import Foundation
import SyzygyFoundation

// MARK: - RemoteConfigProvider Protocol

/// Defines the contract for fetching and reading remote configuration values.
public protocol RemoteConfigProvider: Sendable {
    /// Fetches the remote configuration. Falls back to defaults on failure.
    func fetch() async
    /// Returns the typed `String` value for `key`, or `nil`.
    func string(forKey key: String) -> String?
    /// Returns the typed `Int` value for `key`, or `nil`.
    func int(forKey key: String) -> Int?
    /// Returns the typed `Bool` value for `key`, or `nil`.
    func bool(forKey key: String) -> Bool?
    /// Returns the typed `Double` value for `key`, or `nil`.
    func double(forKey key: String) -> Double?
    /// The timestamp of the most recent successful fetch, or `nil` if never fetched.
    var lastFetchDate: Date? { get }
}

// MARK: - NetworkedRemoteConfigProvider

/// A `RemoteConfigProvider` that fetches config from a remote endpoint via a `NetworkClientProtocol`.
/// Falls back to in-memory defaults when the network is unavailable.
public final class NetworkedRemoteConfigProvider: RemoteConfigProvider, @unchecked Sendable {

    private let client: any NetworkClientProtocol
    private let endpoint: String
    private var defaults: [String: Any]
    /// The cache time-to-live in seconds. A cached response is returned without a network
    /// request while `Date() - lastFetchDate < cacheTtlSeconds`.
    public let cacheTtlSeconds: TimeInterval

    private let lock = NSLock()
    nonisolated(unsafe) private var store: [String: Any]
    nonisolated(unsafe) private var _lastFetchDate: Date?

    /// Initialises the provider.
    /// - Parameters:
    ///   - client: The network client used to fetch remote config.
    ///   - endpoint: The URL string of the remote config endpoint.
    ///   - defaults: Default values returned when a key is not present in the fetched config.
    ///   - cacheTtlSeconds: How long (in seconds) a successful fetch result is considered fresh
    ///     before the next `fetch()` call hits the network again. Defaults to 3600 (one hour).
    public init(
        client: any NetworkClientProtocol,
        endpoint: String,
        defaults: [String: Any] = [:],
        cacheTtlSeconds: TimeInterval = 3600
    ) {
        self.client = client
        self.endpoint = endpoint
        self.defaults = defaults
        self.cacheTtlSeconds = cacheTtlSeconds
        self.store = defaults
    }

    /// Fetches the remote configuration, respecting the cache TTL.
    ///
    /// If a successful fetch occurred within `cacheTtlSeconds`, this method returns
    /// immediately without making a network request. Otherwise it fetches from the
    /// configured endpoint and updates both the in-memory store and `lastFetchDate`.
    public func fetch() async {
        // Return cached result if still within TTL
        let isFresh = lock.withLock { () -> Bool in
            guard let last = _lastFetchDate else { return false }
            return Date().timeIntervalSince(last) < cacheTtlSeconds
        }
        guard !isFresh else { return }

        let request = NetworkRequest(url: endpoint, method: .get)
        do {
            let response = try await client.execute(request)
            guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
                return
            }
            lock.withLock {
                // Merge: remote values override defaults
                var merged = defaults
                json.forEach { merged[$0.key] = $0.value }
                store = merged
                _lastFetchDate = Date()
            }
        } catch {
            // Network failure — silently retain existing store (defaults)
        }
    }

    public func string(forKey key: String) -> String? {
        lock.withLock { store[key] as? String }
    }

    public func int(forKey key: String) -> Int? {
        lock.withLock { store[key] as? Int }
    }

    public func bool(forKey key: String) -> Bool? {
        lock.withLock { store[key] as? Bool }
    }

    public func double(forKey key: String) -> Double? {
        lock.withLock { store[key] as? Double }
    }

    public var lastFetchDate: Date? {
        lock.withLock { _lastFetchDate }
    }
}

// MARK: - InMemoryRemoteConfigProvider

/// An in-memory `RemoteConfigProvider` useful for testing and previews.
public final class InMemoryRemoteConfigProvider: RemoteConfigProvider, @unchecked Sendable {

    private let lock = NSLock()
    nonisolated(unsafe) private var store: [String: Any]
    nonisolated(unsafe) private var _lastFetchDate: Date?

    /// Initialises the provider with an optional initial store.
    public init(initialValues: [String: Any] = [:]) {
        self.store = initialValues
    }

    public func fetch() async {
        lock.withLock { _lastFetchDate = Date() }
    }

    public func string(forKey key: String) -> String? {
        lock.withLock { store[key] as? String }
    }

    public func int(forKey key: String) -> Int? {
        lock.withLock { store[key] as? Int }
    }

    public func bool(forKey key: String) -> Bool? {
        lock.withLock { store[key] as? Bool }
    }

    public func double(forKey key: String) -> Double? {
        lock.withLock { store[key] as? Double }
    }

    public var lastFetchDate: Date? {
        lock.withLock { _lastFetchDate }
    }

    /// Sets a value directly (for testing).
    public func setValue(_ value: Any?, forKey key: String) {
        lock.withLock { store[key] = value }
    }
}
