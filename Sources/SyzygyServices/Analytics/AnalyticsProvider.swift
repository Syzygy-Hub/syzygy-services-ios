import Foundation
import SyzygyFoundation

// MARK: - Protocol

/// Defines the contract for recording analytics events.
public protocol AnalyticsProvider: Sendable {
    /// Records an analytics event with the given name and optional properties.
    func track(event: String, properties: [String: String])
}

// MARK: - Console Stub Implementation

/// An `AnalyticsProvider` that logs events to the console.
public final class ConsoleAnalyticsProvider: AnalyticsProvider {
    /// Initialises the provider.
    public init() {}

    public func track(event: String, properties: [String: String]) {
        print("[Analytics] \(event) \(properties)")
    }
}
