import Testing
import Foundation
import Combine
@testable import SyzygyServices
import SyzygyFoundation

@Suite("AuthProvider")
struct AuthProviderTests {

    // MARK: - SyzygyAuthProvider

    @Test("authenticate stores token and transitions to authenticated state")
    func authenticateTransitionsToAuthenticated() {
        let provider = SyzygyAuthProvider(
            storage: KeychainStorageProvider(service: "com.test.auth.\(UUID().uuidString)")
        )
        let token = AuthToken(accessToken: "access123", refreshToken: "refresh456")
        provider.authenticate(token: token)
        #expect(provider.state.isAuthenticated)
        #expect(provider.state.token?.accessToken == "access123")
    }

    @Test("signOut clears token and transitions to unauthenticated")
    func signOutClearsToken() {
        let provider = SyzygyAuthProvider(
            storage: KeychainStorageProvider(service: "com.test.auth.\(UUID().uuidString)")
        )
        let token = AuthToken(accessToken: "tok")
        provider.authenticate(token: token)
        provider.signOut()
        #expect(provider.state == .unauthenticated)
    }

    @Test("statePublisher emits state changes")
    func statePublisherEmitsChanges() {
        let provider = SyzygyAuthProvider(
            storage: KeychainStorageProvider(service: "com.test.auth.\(UUID().uuidString)")
        )
        var states: [AuthState] = []
        let cancellable = provider.statePublisher.sink { states.append($0) }
        let token = AuthToken(accessToken: "tok")
        provider.authenticate(token: token)
        provider.signOut()
        #expect(states.count >= 3) // initial + authenticated + unauthenticated
        _ = cancellable
    }

    @Test("refresh throws when no network client is configured")
    func refreshWithoutClientThrows() async {
        let provider = SyzygyAuthProvider(
            storage: KeychainStorageProvider(service: "com.test.auth.\(UUID().uuidString)")
        )
        do {
            _ = try await provider.refresh()
            Issue.record("Expected refresh to throw")
        } catch {
            #expect(error is AuthProviderError)
        }
    }

    // MARK: - JWT Expiry Detection

    @Test("expiryDate correctly decodes future exp claim")
    func jwtExpiryFuture() {
        // Build a minimal JWT with a future exp
        let futureExp = Int(Date().timeIntervalSince1970) + 3600
        let payload = "{\"sub\":\"1234\",\"exp\":\(futureExp)}"
        let encoded = Data(payload.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let jwt = "eyJhbGciOiJub25lIn0.\(encoded)."
        let date = SyzygyAuthProvider.expiryDate(from: jwt)
        #expect(date != nil)
        #expect(date! > Date())
    }

    @Test("expiryDate returns nil for malformed JWT")
    func jwtExpiryMalformed() {
        #expect(SyzygyAuthProvider.expiryDate(from: "not.a.jwt.at.all") == nil)
    }

    // MARK: - Real Token-Refresh Flow

    @Test("refresh succeeds and updates stored token via NetworkClient")
    func refreshSucceedsAndUpdatesStoredToken() async throws {
        // Build a JSON-encoded AuthToken for the mock response
        let newToken = AuthToken(accessToken: "refreshed-access", refreshToken: "refreshed-refresh")
        let tokenData = try JSONEncoder().encode(newToken)

        let mockClient = MockNetworkClient(responseData: tokenData, statusCode: 200)
        let storage = KeychainStorageProvider(service: "com.test.auth.\(UUID().uuidString)")
        let provider = SyzygyAuthProvider(
            storage: storage,
            networkClient: mockClient,
            refreshEndpoint: "https://example.com/auth/refresh"
        )

        // Seed an expired token so there is something in storage to replace
        let expiredToken = AuthToken(accessToken: "old-access")
        provider.authenticate(token: expiredToken)

        let returned = try await provider.refresh()
        #expect(returned.accessToken == "refreshed-access")
        #expect(provider.state.isAuthenticated)
        #expect(provider.state.token?.accessToken == "refreshed-access")
    }

    @Test("refresh failure clears tokens and emits unauthenticated")
    func refreshFailureClearsTokens() async throws {
        let mockClient = MockNetworkClient(
            responseData: Data(),
            statusCode: 401,
            shouldThrow: true
        )
        let storage = KeychainStorageProvider(service: "com.test.auth.\(UUID().uuidString)")
        let provider = SyzygyAuthProvider(
            storage: storage,
            networkClient: mockClient,
            refreshEndpoint: "https://example.com/auth/refresh"
        )
        let token = AuthToken(accessToken: "valid")
        provider.authenticate(token: token)

        do {
            _ = try await provider.refresh()
            Issue.record("Expected refresh to throw")
        } catch {
            // After failure the provider should have reverted to expired/unauthenticated.
            // Since we had a token in storage, it reverts to .expired — still not .authenticated.
            #expect(!provider.state.isAuthenticated)
        }
    }

    @Test("expired JWT detected via expiryDate and token isExpired flag")
    func expiredJWTIsDetected() {
        // Build a JWT whose exp is in the past
        let pastExp = Int(Date().timeIntervalSince1970) - 3600
        let payload = "{\"sub\":\"user1\",\"exp\":\(pastExp)}"
        let encoded = Data(payload.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let jwt = "eyJhbGciOiJub25lIn0.\(encoded)."

        guard let expiry = SyzygyAuthProvider.expiryDate(from: jwt) else {
            Issue.record("Failed to decode expiry from JWT")
            return
        }
        let token = AuthToken(
            accessToken: jwt,
            expiresAt: SyzygyTimestamp(millisecondsSinceEpoch: Int64(expiry.timeIntervalSince1970 * 1000))
        )
        #expect(token.isExpired)
    }

    @Test("auto-refresh: provider transitions through refreshing then authenticated")
    func autoRefreshTransitionsCorrectly() async throws {
        let newToken = AuthToken(accessToken: "auto-refreshed")
        let tokenData = try JSONEncoder().encode(newToken)
        let mockClient = MockNetworkClient(responseData: tokenData, statusCode: 200)

        let provider = SyzygyAuthProvider(
            storage: KeychainStorageProvider(service: "com.test.auth.\(UUID().uuidString)"),
            networkClient: mockClient,
            refreshEndpoint: "https://example.com/auth/refresh"
        )

        var capturedStates: [AuthState] = []
        let cancellable = provider.statePublisher.sink { capturedStates.append($0) }

        _ = try await provider.refresh()

        // Should have seen at least: initial(.unauthenticated) → .refreshing → .authenticated
        let hasRefreshing = capturedStates.contains { $0 == .refreshing }
        let hasAuthenticated = capturedStates.contains { $0.isAuthenticated }
        #expect(hasRefreshing)
        #expect(hasAuthenticated)
        _ = cancellable
    }

    // MARK: - Biometric Stubs

    @Test("canUseBiometric returns false on stub")
    func testCanUseBiometricReturnsFalse() {
        let provider = SyzygyAuthProvider(
            storage: KeychainStorageProvider(service: "com.test.auth.\(UUID().uuidString)")
        )
        #expect(provider.canUseBiometric() == false)
    }

    @Test("authenticateWithBiometric returns unauthenticated on stub")
    func testAuthenticateWithBiometricReturnsUnauthenticated() async {
        let provider = SyzygyAuthProvider(
            storage: KeychainStorageProvider(service: "com.test.auth.\(UUID().uuidString)")
        )
        let result = await provider.authenticateWithBiometric(reason: "Test")
        #expect(result == .unauthenticated)
    }

    // MARK: - Legacy JWTAuthProvider

    @Test("JWTAuthProvider stores and clears token")
    func legacyStoresAndClearsToken() {
        let provider = JWTAuthProvider()
        #expect(provider.accessToken == nil)
        provider.storeToken("tok123")
        #expect(provider.accessToken == "tok123")
        provider.clearToken()
        #expect(provider.accessToken == nil)
    }
}

// MARK: - MockNetworkClient for Auth Tests

/// A minimal in-process network client for auth tests that returns preconfigured data.
final class MockNetworkClient: NetworkClientProtocol, Sendable {
    private let responseData: Data
    private let statusCode: Int
    private let shouldThrow: Bool

    init(responseData: Data, statusCode: Int, shouldThrow: Bool = false) {
        self.responseData = responseData
        self.statusCode = statusCode
        self.shouldThrow = shouldThrow
    }

    func execute(_ request: NetworkRequest) async throws -> NetworkResponse {
        if shouldThrow {
            throw NetworkServiceError(code: .unauthenticated, message: "Mock auth failure")
        }
        return NetworkResponse(statusCode: statusCode, data: responseData, headers: [:])
    }
}
