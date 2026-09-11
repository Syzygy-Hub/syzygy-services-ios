import Testing
@testable import SyzygyServices

@Suite("NetworkClient")
struct NetworkClientTests {
    @Test("URLSessionNetworkClient initialises without error")
    func initialisesWithoutError() {
        let client = URLSessionNetworkClient()
        #expect(client != nil)
    }
}
