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
