import Foundation
import SyzygyFoundation

// MARK: - Interceptor Protocol

/// A request/response interceptor that can modify or observe network traffic.
public protocol RequestInterceptor: Sendable {
    /// Called before a request is sent. Returns the (possibly modified) request.
    func adapt(_ request: NetworkRequest) async throws -> NetworkRequest
    /// Called after a response is received.
    func didReceive(_ response: NetworkResponse, for request: NetworkRequest)
}

public extension RequestInterceptor {
    func adapt(_ request: NetworkRequest) async throws -> NetworkRequest { request }
    func didReceive(_ response: NetworkResponse, for request: NetworkRequest) {}
}

// MARK: - NetworkServiceError

/// A network-layer error conforming to `SyzygyError`.
public struct NetworkServiceError: SyzygyError {
    public let code: SyzygyErrorCode
    public let message: String
    public let severity: SyzygyErrorSeverity
    public let underlyingError: (any Error)?

    /// Creates a `NetworkServiceError`.
    public init(
        code: SyzygyErrorCode,
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

// MARK: - BackoffClock

/// A clock abstraction used by `URLSessionNetworkClient` for retry back-off delays.
///
/// Inject a `MockBackoffClock` in tests to make retry timing deterministic and
/// instantaneous, matching the coroutine-test-scheduler pattern on Android.
public protocol BackoffClock: Sendable {
    /// Suspends the caller for the given number of nanoseconds.
    func sleep(nanoseconds: UInt64) async throws
}

/// The default `BackoffClock` that delegates to `Task.sleep`.
public struct TaskBackoffClock: BackoffClock {
    public init() {}
    public func sleep(nanoseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

// MARK: - URLSessionNetworkClient

/// A URLSession-backed `NetworkClientProtocol` with interceptors and exponential-backoff retry.
public actor URLSessionNetworkClient: NetworkClientProtocol {

    private let session: URLSession
    private let ownsSession: Bool
    private let interceptors: [any RequestInterceptor]
    private let maxRetries: Int
    private let clock: any BackoffClock
    private let logger: (any LoggerProtocol)?
    private var isDisposed = false

    /// Initialises the client with an injected URLSession.
    ///
    /// The caller retains ownership of the session; `dispose()` will **not** invalidate it.
    /// - Parameters:
    ///   - session: The URLSession to use. Defaults to `.shared`.
    ///   - interceptors: Request/response interceptors applied in order.
    ///   - maxRetries: Maximum retry attempts with exponential backoff (default 3).
    ///   - clock: Back-off clock used for retry delays. Defaults to `TaskBackoffClock`
    ///     (real `Task.sleep`). Inject a `MockBackoffClock` in tests for deterministic timing.
    ///   - logger: Optional logger for request/response/error diagnostics. `nil` = zero overhead.
    public init(
        session: URLSession = .shared,
        interceptors: [any RequestInterceptor] = [],
        maxRetries: Int = 3,
        clock: any BackoffClock = TaskBackoffClock(),
        logger: (any LoggerProtocol)? = nil
    ) {
        self.session = session
        self.ownsSession = false
        self.interceptors = interceptors
        self.maxRetries = maxRetries
        self.clock = clock
        self.logger = logger
    }

    /// Initialises the client by creating a new URLSession internally.
    ///
    /// The client owns the created session and will invalidate it on `dispose()`.
    /// - Parameters:
    ///   - configuration: URLSession configuration for the internally-created session.
    ///   - interceptors: Request/response interceptors applied in order.
    ///   - maxRetries: Maximum retry attempts with exponential backoff (default 3).
    ///   - clock: Back-off clock used for retry delays.
    ///   - logger: Optional logger for diagnostics.
    public init(
        configuration: URLSessionConfiguration,
        interceptors: [any RequestInterceptor] = [],
        maxRetries: Int = 3,
        clock: any BackoffClock = TaskBackoffClock(),
        logger: (any LoggerProtocol)? = nil
    ) {
        self.session = URLSession(configuration: configuration)
        self.ownsSession = true
        self.interceptors = interceptors
        self.maxRetries = maxRetries
        self.clock = clock
        self.logger = logger
    }

    /// Cancels all pending tasks and marks the client as disposed.
    /// After calling this, `execute(_:)` throws `NetworkServiceError` with code `.cancelled`.
    /// The underlying URLSession is only invalidated when the client owns it (i.e. it was
    /// created via `init(configuration:…)`). Injected sessions are left intact.
    public func dispose() {
        isDisposed = true
        if ownsSession {
            session.invalidateAndCancel()
        }
    }

    /// Executes the given network request, applying interceptors and retry logic.
    public func execute(_ request: NetworkRequest) async throws -> NetworkResponse {
        guard !isDisposed else {
            throw NetworkServiceError(code: .cancelled, message: "NetworkClient has been disposed")
        }
        // Log request — redact sensitive headers to avoid leaking credentials.
        if let logger {
            let safeHeaders = request.headers.filter { pair in
                !Self.redactedHeaders.contains(pair.key.lowercased())
            }
            logger.debug(
                "→ \(request.method.rawValue) \(request.url)",
                metadata: [
                    "headers": safeHeaders.map { "\($0.key): \($0.value)" }.joined(separator: ", "),
                    "bodySize": "\(request.body?.count ?? 0)"
                ]
            )
        }
        var adapted = request
        for interceptor in interceptors {
            adapted = try await interceptor.adapt(adapted)
        }
        return try await executeWithRetry(adapted, attempt: 0)
    }

    // MARK: - Private

    /// Headers whose values must never appear in logs. Comparison is case-insensitive.
    private static let redactedHeaders: Set<String> = [
        "authorization", "cookie", "x-api-key", "proxy-authorization"
    ]

    private func executeWithRetry(_ request: NetworkRequest, attempt: Int) async throws -> NetworkResponse {
        do {
            let start = Date()
            let response = try await performRequest(request)
            let elapsed = Date().timeIntervalSince(start)
            // Log response
            logger?.debug(
                "← \(response.statusCode) \(request.url)",
                metadata: ["durationMs": String(format: "%.0f", elapsed * 1000), "bodySize": "\(response.data.count)"]
            )
            for interceptor in interceptors {
                interceptor.didReceive(response, for: request)
            }
            if response.isServerError && attempt < maxRetries {
                try await backoff(attempt)
                return try await executeWithRetry(request, attempt: attempt + 1)
            }
            if response.isClientError {
                throw clientError(for: response)
            }
            return response
        } catch let error as NetworkServiceError {
            let meta = ["code": error.code.rawValue]
            logger?.error("✗ \(request.method.rawValue) \(request.url)", error: error, metadata: meta)
            throw error
        } catch {
            if attempt < maxRetries && isRetryable(error) {
                try await backoff(attempt)
                return try await executeWithRetry(request, attempt: attempt + 1)
            }
            let mapped = mapError(error)
            let meta = ["code": mapped.code.rawValue]
            logger?.error("✗ \(request.method.rawValue) \(request.url)", error: mapped, metadata: meta)
            throw mapped
        }
    }

    private func performRequest(_ request: NetworkRequest) async throws -> NetworkResponse {
        guard let url = URL(string: request.url) else {
            throw NetworkServiceError(code: .unknown, message: "Invalid URL: \(request.url)")
        }
        var urlRequest = URLRequest(url: url, timeoutInterval: request.timeoutSeconds)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkServiceError(code: .unknown, message: "Non-HTTP response")
        }
        let headers = (http.allHeaderFields as? [String: String]) ?? [:]
        return NetworkResponse(statusCode: http.statusCode, data: data, headers: headers)
    }

    private func clientError(for response: NetworkResponse) -> NetworkServiceError {
        let code: SyzygyErrorCode
        switch response.statusCode {
        case 401: code = .unauthenticated
        case 403: code = .forbidden
        case 404: code = .notFound
        default: code = SyzygyErrorCode(rawValue: "client_error_\(response.statusCode)")
        }
        return NetworkServiceError(code: code, message: "HTTP \(response.statusCode)")
    }

    private func mapError(_ error: any Error) -> NetworkServiceError {
        let nsError = error as NSError
        if nsError.code == NSURLErrorTimedOut {
            return NetworkServiceError(code: .timeout, message: "Request timed out", underlyingError: error)
        }
        if nsError.code == NSURLErrorCancelled {
            return NetworkServiceError(code: .cancelled, message: "Request cancelled", underlyingError: error)
        }
        if nsError.domain == NSURLErrorDomain {
            return NetworkServiceError(
                code: .networkUnavailable, message: nsError.localizedDescription, underlyingError: error
            )
        }
        return NetworkServiceError(code: .unknown, message: error.localizedDescription, underlyingError: error)
    }

    private func isRetryable(_ error: any Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        let retryCodes: [Int] = [
            NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet
        ]
        return retryCodes.contains(nsError.code)
    }

    // Canonical backoff policy (all 4 platforms must match):
    // delay = random(0, min(cap, base * multiplier^attempt))
    private static let backoffBaseMs: Double = 500
    private static let backoffMultiplier: Double = 2.0
    private static let backoffCapMs: Double = 8_000
    static let maxRetryAttempts: Int = 3

    private func backoff(_ attempt: Int) async throws {
        let base = URLSessionNetworkClient.backoffBaseMs
        let cap = URLSessionNetworkClient.backoffCapMs
        let multiplier = URLSessionNetworkClient.backoffMultiplier
        let ceiling = min(cap, base * pow(multiplier, Double(attempt)))
        let delayMs = Double.random(in: 0...ceiling)
        let nanoseconds = UInt64(delayMs * 1_000_000)
        try await clock.sleep(nanoseconds: nanoseconds)
    }
}
