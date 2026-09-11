import Testing
@testable import SyzygyServices

@Suite("WebSocketProvider")
struct WebSocketProviderTests {
    @Test("URLSessionWebSocketProvider initialises without error")
    func initialisesWithoutError() {
        let provider = URLSessionWebSocketProvider()
        #expect(provider != nil)
    }
}
