import Testing
@testable import SyzygyServices

@Suite("AuthProvider")
struct AuthProviderTests {
    @Test("JWTAuthProvider stores and clears token")
    func storesAndClearsToken() {
        let provider = JWTAuthProvider()
        #expect(provider.accessToken == nil)
        provider.storeToken("tok123")
        #expect(provider.accessToken == "tok123")
        provider.clearToken()
        #expect(provider.accessToken == nil)
    }
}
