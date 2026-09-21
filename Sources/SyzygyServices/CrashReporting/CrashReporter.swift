import Foundation
import SyzygyFoundation

// MARK: - Breadcrumb

/// A single navigation/event breadcrumb for crash context.
public struct Breadcrumb: Sendable {
    /// A human-readable message describing the breadcrumb event.
    public let message: String
    /// Optional key-value metadata attached to the breadcrumb.
    public let metadata: [String: String]
    /// When the breadcrumb was recorded.
    public let timestamp: Date

    public init(message: String, metadata: [String: String] = [:], timestamp: Date = Date()) {
        self.message = message
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

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
    /// Leaves a breadcrumb for crash context. Stored in a circular buffer (last 20 kept).
    func leaveBreadcrumb(message: String, metadata: [String: String]?)
    /// Clears all stored breadcrumbs.
    func clearBreadcrumbs()
}

// MARK: - ConsoleCrashReporter

/// A `CrashReporter` that logs events to the console and stores context in memory.
public final class ConsoleCrashReporter: CrashReporter, @unchecked Sendable {

    private static let maxBreadcrumbs = 20

    private let lock = NSLock()
    nonisolated(unsafe) private var metadata: [String: String] = [:]
    nonisolated(unsafe) private var userContext: (userId: String, email: String?)?
    /// Circular buffer of the most recent breadcrumbs (capped at `maxBreadcrumbs`).
    nonisolated(unsafe) private var breadcrumbs: [Breadcrumb] = []

    /// Output sink — defaults to `print`. Override in tests to capture log lines.
    nonisolated(unsafe) internal var logger: (String) -> Void = { print($0) }

    /// Initialises the reporter.
    public init() {}

    public func recordError(_ error: any Error, metadata extra: [String: String]) {
        let ctx = lock.withLock { mergedContext(with: extra) }
        logger("[CrashReporter] NON-FATAL error=\(error) context=\(RedactionPolicy.redactMap(ctx))")
    }

    public func reportCrash(message: String, metadata extra: [String: String]) {
        let (ctx, crumbs) = lock.withLock { (mergedContext(with: extra), breadcrumbs) }
        let crumbsDescription = crumbs.map { "[\($0.message)]" }.joined(separator: ", ")
        let redacted = RedactionPolicy.redactMap(ctx)
        logger("[CrashReporter] CRASH message=\(message) context=\(redacted) breadcrumbs=[\(crumbsDescription)]")
        // Stub: in production this would forward to a crash-reporting SDK.
    }

    public func setUserContext(userId: String, email: String?) {
        lock.withLock {
            userContext = (userId: userId, email: email)
        }
        let redactedUserId = RedactionPolicy.redact(key: "userId", value: userId)
        let redactedEmail = email.map { RedactionPolicy.redact(key: "email", value: $0) } ?? "nil"
        logger("[CrashReporter] setUserContext userId=\(redactedUserId) email=\(redactedEmail)")
    }

    public func setMetadata(key: String, value: String) {
        lock.withLock { metadata[key] = value }
        logger("[CrashReporter] setMetadata \(key)=\(RedactionPolicy.redact(key: key, value: value))")
    }

    public func leaveBreadcrumb(message: String, metadata: [String: String]? = nil) {
        lock.withLock {
            if breadcrumbs.count >= ConsoleCrashReporter.maxBreadcrumbs {
                breadcrumbs.removeFirst()
            }
            breadcrumbs.append(Breadcrumb(message: message, metadata: metadata ?? [:]))
        }
        logger("[CrashReporter] breadcrumb=\(message) metadata=\(RedactionPolicy.redactMap(metadata ?? [:]))")
    }

    public func clearBreadcrumbs() {
        lock.withLock { breadcrumbs.removeAll() }
        logger("[CrashReporter] clearBreadcrumbs")
    }

    /// Returns a snapshot of the stored metadata (for testing).
    public func currentMetadata() -> [String: String] {
        lock.withLock { metadata }
    }

    /// Returns the stored user context, if any (for testing).
    public func currentUserContext() -> (userId: String, email: String?)? {
        lock.withLock { userContext }
    }

    /// Returns the current breadcrumb buffer (for testing).
    public func currentBreadcrumbs() -> [Breadcrumb] {
        lock.withLock { breadcrumbs }
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
