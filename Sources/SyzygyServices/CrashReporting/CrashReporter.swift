import Foundation
import SyzygyFoundation

// MARK: - CrashReporter Protocol

/// Defines the contract for crash and non-fatal error reporting.
public protocol CrashReporter: Sendable {
    /// Records a non-fatal error with optional metadata.
    func recordError(_ error: any Error, metadata: [String: String])
    /// Logs a fatal crash (stub — does not terminate the process).
    func reportCrash(message: String, metadata: [String: String])
    /// Sets identifying context for the current user.
    func setUserContext(userId: String, email: String?)
    /// Stores a custom key-value pair for context in crash reports.
    func setMetadata(key: String, value: String)
}

// MARK: - ConsoleCrashReporter

/// A `CrashReporter` that logs events to the console and stores context in memory.
public final class ConsoleCrashReporter: CrashReporter, @unchecked Sendable {

    private let lock = NSLock()
    nonisolated(unsafe) private var metadata: [String: String] = [:]
    nonisolated(unsafe) private var userContext: (userId: String, email: String?)?

    /// Initialises the reporter.
    public init() {}

    public func recordError(_ error: any Error, metadata extra: [String: String]) {
        let ctx = lock.withLock { mergedContext(with: extra) }
        print("[CrashReporter] NON-FATAL error=\(error) context=\(ctx)")
    }

    public func reportCrash(message: String, metadata extra: [String: String]) {
        let ctx = lock.withLock { mergedContext(with: extra) }
        print("[CrashReporter] CRASH message=\(message) context=\(ctx)")
        // Stub: in production this would forward to a crash-reporting SDK.
    }

    public func setUserContext(userId: String, email: String?) {
        lock.withLock {
            userContext = (userId: userId, email: email)
        }
        print("[CrashReporter] setUserContext userId=\(userId) email=\(email ?? "nil")")
    }

    public func setMetadata(key: String, value: String) {
        lock.withLock { metadata[key] = value }
        print("[CrashReporter] setMetadata \(key)=\(value)")
    }

    /// Returns a snapshot of the stored metadata (for testing).
    public func currentMetadata() -> [String: String] {
        lock.withLock { metadata }
    }

    /// Returns the stored user context, if any (for testing).
    public func currentUserContext() -> (userId: String, email: String?)? {
        lock.withLock { userContext }
    }

    // MARK: - Private

    private func mergedContext(with extra: [String: String]) -> [String: String] {
        var ctx = metadata
        extra.forEach { ctx[$0.key] = $0.value }
        if let user = userContext {
            ctx["userId"] = user.userId
            if let email = user.email { ctx["email"] = email }
        }
        return ctx
    }
}
