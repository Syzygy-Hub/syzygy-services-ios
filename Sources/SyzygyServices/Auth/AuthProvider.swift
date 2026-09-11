import Foundation
import SyzygyFoundation

// MARK: - Protocol

/// Defines the contract for authentication and token management.
public protocol AuthProvider: Sendable {
    /// Returns the current access token, or nil if unauthenticated.
    var accessToken: String? { get }
    /// Stores the given access token.
    func storeToken(_ token: String)
    /// Clears the current access token.
    func clearToken()
    /// Refreshes the access token. Returns the new token or throws on failure.
    func refreshToken() async throws -> String
}

// MARK: - JWT Stub Implementation

/// An `AuthProvider` that stores a JWT token in memory and provides a stub refresh.
public final class JWTAuthProvider: AuthProvider {
    nonisolated(unsafe) private var _accessToken: String?

    /// Initialises the provider with an optional pre-existing token.
    public init(token: String? = nil) {
        self._accessToken = token
    }

    public var accessToken: String? { _accessToken }

    public func storeToken(_ token: String) {
        _accessToken = token
    }

    public func clearToken() {
        _accessToken = nil
    }

    public func refreshToken() async throws -> String {
        // Stub — replace with real token-refresh network call.
        throw AuthError.refreshNotImplemented
    }
}

/// Errors thrown by `JWTAuthProvider`.
public enum AuthError: Error {
    /// Token refresh is not yet implemented.
    case refreshNotImplemented
}
