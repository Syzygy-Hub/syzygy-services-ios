import Foundation
import SyzygyFoundation

// MARK: - Protocol

/// Defines the contract for crash and non-fatal error reporting.
public protocol CrashReporter: Sendable {
    /// Reports a fatal crash with the given message.
    func reportCrash(message: String, metadata: [String: String])
    /// Records a non-fatal error.
    func recordError(_ error: Error, metadata: [String: String])
}

// MARK: - Console Stub Implementation

/// A `CrashReporter` that logs crash and error events to the console.
public final class ConsoleCrashReporter: CrashReporter {
    /// Initialises the reporter.
    public init() {}

    public func reportCrash(message: String, metadata: [String: String]) {
        print("[CrashReporter] CRASH: \(message) \(metadata)")
    }

    public func recordError(_ error: Error, metadata: [String: String]) {
        print("[CrashReporter] ERROR: \(error) \(metadata)")
    }
}
