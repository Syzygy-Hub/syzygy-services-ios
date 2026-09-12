import Testing
import Foundation
@testable import SyzygyServices

@Suite("WebSocketProvider")
struct WebSocketProviderTests {

    @Test("initial connectionState is disconnected")
    func initialStateIsDisconnected() async {
        let provider = URLSessionWebSocketProvider()
        let state = await provider.connectionState
        #expect(state == .disconnected)
    }

    @Test("disconnect without connecting does not crash")
    func disconnectWithoutConnecting() async {
        let provider = URLSessionWebSocketProvider()
        await provider.disconnect()
        let state = await provider.connectionState
        #expect(state == .disconnected)
    }

    @Test("send text throws notConnected when disconnected")
    func sendThrowsWhenNotConnected() async {
        let provider = URLSessionWebSocketProvider()
        do {
            try await provider.send(text: "hello")
            Issue.record("Expected notConnected error")
        } catch WebSocketError.notConnected {
            #expect(true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("send data throws notConnected when disconnected")
    func sendDataThrowsWhenNotConnected() async {
        let provider = URLSessionWebSocketProvider()
        do {
            try await provider.send(data: Data("binary".utf8))
            Issue.record("Expected notConnected error")
        } catch WebSocketError.notConnected {
            #expect(true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("messages() returns an AsyncStream that finishes on disconnect")
    func messagesReturnsAsyncStream() async {
        let provider = URLSessionWebSocketProvider()
        let stream = await provider.messages()
        var iterator = stream.makeAsyncIterator()
        // Disconnect immediately to finish the stream
        await provider.disconnect()
        let msg = await iterator.next()
        #expect(msg == nil)
    }

    @Test("WebSocketConnectionState values are distinct")
    func connectionStateValues() {
        #expect(WebSocketConnectionState.disconnected != .connected)
        #expect(WebSocketConnectionState.connecting != .connected)
        #expect(WebSocketConnectionState.disconnected != .connecting)
    }
}
