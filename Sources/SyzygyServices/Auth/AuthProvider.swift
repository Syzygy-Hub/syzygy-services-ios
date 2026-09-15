import Foundation
import Combine
import SyzygyFoundation

// MARK: - SyzygyAuthProvider

/// A Combine-based `SyzygyFoundation.AuthProvider` that stores JWT tokens in the Keychain.
///
/// - Decodes the JWT `exp` claim to detect expiry.
/// - Persists the token via a `KeychainStorageProvider`.
/// - Publishes `AuthState` changes via `statePublisher`.
public final class SyzygyAuthProvider: SyzygyFoundation.AuthProvider, @unchecked Sendable {

    // MARK: - Keys

    private static let tokenKey = StorageKey<AuthToken>(identifier: "com.syzygy.auth.token")

    // MARK: - State

    private let subject: CurrentValueSubject<AuthState, Never>
    private let storage: KeychainStorageProvider
    private let lock = NSLock()
    private var networkClient: (any NetworkClientProtocol)?
    private var refreshEndpoint: String

    /// The Combine publisher for auth state changes.
    public var statePublisher: AnyPublisher<AuthState, Never> {
        subject.eraseToAnyPublisher()
    }

    /// The current auth state.
    public var state: AuthState {
        subject.value
    }

    /// Initialises the provider.
    /// - Parameters:
    ///   - storage: Keychain storage for persisting the token.
    ///   - networkClient: Optional network client used for token refresh.
    ///   - refreshEndpoint: The URL string for the refresh endpoint.
    public init(
        storage: KeychainStorageProvider = KeychainStorageProvider(),
        networkClient: (any NetworkClientProtocol)? = nil,
        refreshEndpoint: String = ""
    ) {
        self.storage = storage
        self.networkClient = networkClient
        self.refreshEndpoint = refreshEndpoint

        // Restore persisted token
        if let token = storage.get(SyzygyAuthProvider.tokenKey) {
            if token.isExpired {
                self.subject = CurrentValueSubject(.expired(token: token))
            } else {
                self.subject = CurrentValueSubject(.authenticated(token: token))
            }
        } else {
            self.subject = CurrentValueSubject(.unauthenticated)
        }
    }

    /// Stores the given token and transitions to `.authenticated`.
    public func authenticate(token: AuthToken) {
        lock.withLock {
            storage.set(token, for: SyzygyAuthProvider.tokenKey)
            subject.send(.authenticated(token: token))
        }
    }

    /// Refreshes the access token using the network client.
    public func refresh() async throws -> AuthToken {
        lock.withLock { subject.send(.refreshing) }

        guard let client = networkClient, !refreshEndpoint.isEmpty else {
            // Restore previous state on failure
            lock.withLock {
                if let token = storage.get(SyzygyAuthProvider.tokenKey) {
                    subject.send(.expired(token: token))
                } else {
                    subject.send(.unauthenticated)
                }
            }
            throw AuthProviderError.refreshNotConfigured
        }

        do {
            let request = NetworkRequest(url: refreshEndpoint, method: .post)
            let response = try await client.execute(request)
            let decoder = JSONDecoder()
            let token = try decoder.decode(AuthToken.self, from: response.data)
            authenticate(token: token)
            return token
        } catch {
            lock.withLock {
                if let token = storage.get(SyzygyAuthProvider.tokenKey) {
                    subject.send(.expired(token: token))
                } else {
                    subject.send(.unauthenticated)
                }
            }
            throw error
        }
    }

    /// Signs out and transitions to `.unauthenticated`.
    public func signOut() {
        lock.withLock {
            storage.remove(SyzygyAuthProvider.tokenKey)
            subject.send(.unauthenticated)
        }
    }

    // MARK: - JWT Helpers

    /// Decodes the `exp` claim from a raw JWT string.
    /// Returns nil if the claim is absent or the JWT is malformed.
    public static func expiryDate(from jwt: String) -> Date? {
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        // Base64URL -> Base64
        payload = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = payload + String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: padded),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: exp)
    }
}

// MARK: - Biometric Auth Extension

/// Default biometric stub implementations available to all `AuthProvider` conformers.
///
/// These defaults always return `false` / `.unauthenticated`.
/// Wire `SyzygyAuthProvider` to `LAContext` for real Face ID / Touch ID support.
public extension SyzygyFoundation.AuthProvider {
    /// Returns whether biometric authentication is available on this device.
    /// - Note: Always returns `false` in the stub. Wire to
    ///   `LAContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` for real Face ID / Touch ID.
    func canUseBiometric() -> Bool { false }

    /// Authenticates the user with biometrics (Face ID / Touch ID).
    /// - Parameter reason: The localized reason shown to the user in the system prompt.
    /// - Returns: `.authenticated` if successful, `.unauthenticated` if biometrics unavailable or failed.
    /// - Note: Stub always returns `.unauthenticated`. Wire to `LAContext.evaluatePolicy` for real usage.
    func authenticateWithBiometric(reason: String) async -> AuthState { .unauthenticated }
}

// MARK: - Errors

/// Errors produced by `SyzygyAuthProvider`.
public enum AuthProviderError: Error, Sendable {
    /// Token refresh requires a network client and endpoint to be configured.
    case refreshNotConfigured
    /// The refresh response could not be decoded.
    case invalidRefreshResponse

    // Legacy stub compatibility
    case refreshNotImplemented
}

// MARK: - Legacy aliases

/// Legacy JWT in-memory provider retained for source compatibility.
@available(*, deprecated, renamed: "SyzygyAuthProvider")
public final class JWTAuthProvider: @unchecked Sendable {
    nonisolated(unsafe) private var _accessToken: String?

    /// Initialises the provider with an optional pre-existing token.
    public init(token: String? = nil) { self._accessToken = token }

    /// The current access token.
    public var accessToken: String? { _accessToken }

    /// Stores the given access token.
    public func storeToken(_ token: String) { _accessToken = token }

    /// Clears the current access token.
    public func clearToken() { _accessToken = nil }

    /// Stub refresh — throws `refreshNotConfigured` as this class has no network client.
    /// Migrate to `SyzygyAuthProvider` with a configured `networkClient` and `refreshEndpoint`.
    public func refreshToken() async throws -> String {
        throw AuthProviderError.refreshNotConfigured
    }

    /// Returns whether biometric authentication is available on this device.
    /// Always returns `false` in this stub.
    public func canUseBiometric() -> Bool { false }

    /// Authenticates the user with biometrics.
    /// Always returns `.unauthenticated` in this stub.
    public func authenticateWithBiometric(reason: String) async -> AuthState { .unauthenticated }
}

/// Alias preserved for source compatibility.
public typealias AuthError = AuthProviderError
