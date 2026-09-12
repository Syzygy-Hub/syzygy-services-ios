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

// MARK: - URLSessionNetworkClient

/// A URLSession-backed `NetworkClientProtocol` with interceptors and exponential-backoff retry.
public actor URLSessionNetworkClient: NetworkClientProtocol {

    private let session: URLSession
    private let interceptors: [any RequestInterceptor]
    private let maxRetries: Int

    /// Initialises the client.
    /// - Parameters:
    ///   - session: The URLSession to use. Defaults to `.shared`.
    ///   - interceptors: Request/response interceptors applied in order.
    ///   - maxRetries: Maximum retry attempts with exponential backoff (default 3).
    public init(
        session: URLSession = .shared,
        interceptors: [any RequestInterceptor] = [],
        maxRetries: Int = 3
    ) {
        self.session = session
        self.interceptors = interceptors
        self.maxRetries = maxRetries
    }

    /// Executes the given network request, applying interceptors and retry logic.
    public func execute(_ request: NetworkRequest) async throws -> NetworkResponse {
        var adapted = request
        for interceptor in interceptors {
            adapted = try await interceptor.adapt(adapted)
        }
        return try await executeWithRetry(adapted, attempt: 0)
    }

    // MARK: - Private

    private func executeWithRetry(_ request: NetworkRequest, attempt: Int) async throws -> NetworkResponse {
        do {
            let response = try await performRequest(request)
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
            throw error
        } catch {
            if attempt < maxRetries && isRetryable(error) {
                try await backoff(attempt)
                return try await executeWithRetry(request, attempt: attempt + 1)
            }
            throw mapError(error)
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
            return NetworkServiceError(code: .networkUnavailable, message: nsError.localizedDescription, underlyingError: error)
        }
        return NetworkServiceError(code: .unknown, message: error.localizedDescription, underlyingError: error)
    }

    private func isRetryable(_ error: any Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        let retryCodes = [NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet]
        return retryCodes.contains(nsError.code)
    }

    private func backoff(_ attempt: Int) async throws {
        let nanoseconds = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
