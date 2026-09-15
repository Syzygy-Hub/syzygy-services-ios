import Foundation
import SyzygyFoundation

// MARK: - ConsoleAnalyticsProvider

/// A `SyzygyFoundation.AnalyticsProvider` that logs events to the console.
///
/// Maintains an in-memory record of user properties and a session ID.
public final class ConsoleAnalyticsProvider: SyzygyFoundation.AnalyticsProvider, @unchecked Sendable {

    private let lock = NSLock()
    nonisolated(unsafe) private var userProperties: [String: String] = [:]
    nonisolated(unsafe) private var _sessionId: String
    nonisolated(unsafe) private var _lastTrackedProperties: [String: String]?

    /// The current session identifier (a UUID string generated at init).
    public var sessionId: String {
        lock.withLock { _sessionId }
    }

    /// Initialises the provider, generating a new session ID.
    public init() {
        self._sessionId = UUID().uuidString
    }

    public func track(_ event: AnalyticsEvent) {
        let sessionId = lock.withLock { _sessionId }
        var enriched = event.properties
        enriched["session_id"] = sessionId
        lock.withLock { _lastTrackedProperties = enriched }
        print("[Analytics] event=\(event.name) properties=\(enriched) ts=\(event.timestamp.millisecondsSinceEpoch)")
    }

    /// Returns the enriched properties of the most recently tracked event (for testing).
    public func lastTrackedProperties() -> [String: String]? {
        lock.withLock { _lastTrackedProperties }
    }

    public func identify(userId: String, traits: [String: String]) {
        lock.withLock {
            userProperties["userId"] = userId
            traits.forEach { userProperties[$0.key] = $0.value }
        }
        print("[Analytics] identify userId=\(userId) traits=\(traits)")
    }

    public func reset() {
        lock.withLock {
            userProperties.removeAll()
            _sessionId = UUID().uuidString
        }
        print("[Analytics] reset")
    }

    /// Tracks a screen view event with the given screen name.
    public func trackScreen(_ name: String, properties: [String: String] = [:]) {
        var props = properties
        props["screen_name"] = name
        track(AnalyticsEvent(name: "screen_view", properties: props))
    }

    /// Returns the current in-memory user properties (for testing).
    public func currentUserProperties() -> [String: String] {
        lock.withLock { userProperties }
    }
}
