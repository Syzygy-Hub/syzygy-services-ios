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

    // MARK: - Binary payload tests

    @Test("send binary data throws notConnected when disconnected")
    func sendBinaryDataThrowsWhenNotConnected() async {
        let provider = URLSessionWebSocketProvider()
        let binaryPayload = Data([0xDE, 0xAD, 0xBE, 0xEF])
        do {
            try await provider.send(data: binaryPayload)
            Issue.record("Expected notConnected error for binary send")
        } catch WebSocketError.notConnected {
            #expect(true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("WebSocketMessage.data equality holds for identical payloads")
    func webSocketMessageDataEquality() {
        let payload = Data("binary-payload".utf8)
        let msg1 = WebSocketMessage.data(payload)
        let msg2 = WebSocketMessage.data(payload)
        #expect(msg1 == msg2)
    }

    @Test("WebSocketMessage.text and .data are not equal for same bytes")
    func webSocketMessageTypesAreDistinct() {
        let bytes = Data("hello".utf8)
        let text = WebSocketMessage.text("hello")
        let binary = WebSocketMessage.data(bytes)
        #expect(text != binary)
    }

    @Test("WebSocketMessage binary payload preserves byte content")
    func binaryPayloadPreservesByteContent() {
        let original = Data([0x00, 0xFF, 0x80, 0x7F])
        if case .data(let extracted) = WebSocketMessage.data(original) {
            #expect(extracted == original)
        } else {
            Issue.record("Failed to extract .data payload")
        }
    }

    @Test("Mixed text and binary WebSocketMessage values round-trip correctly")
    func mixedTextAndBinaryMessagesRoundTrip() {
        let textMessage = WebSocketMessage.text("hello world")
        let binaryMessage = WebSocketMessage.data(Data([0x01, 0x02, 0x03]))

        if case .text(let t) = textMessage {
            #expect(t == "hello world")
        } else {
            Issue.record("Expected .text case")
        }

        if case .data(let d) = binaryMessage {
            #expect(d == Data([0x01, 0x02, 0x03]))
        } else {
            Issue.record("Expected .data case")
        }

        // Ensure the two message types remain distinct
        #expect(textMessage != binaryMessage)
    }

    @Test("messages() stream receives binary message yielded by an in-process mock provider")
    func messagesStreamReceivesBinaryPayload() async {
        let binaryPayload = Data([0xCA, 0xFE, 0xBA, 0xBE])
        let provider = InProcessMockWebSocketProvider()
        let stream = await provider.messages()

        // Yield a binary message then finish
        Task {
            await provider.injectMessage(.data(binaryPayload))
            await provider.finish()
        }

        var received: [WebSocketMessage] = []
        for await msg in stream {
            received.append(msg)
        }

        #expect(received.count == 1)
        if case .data(let d) = received.first {
            #expect(d == binaryPayload)
        } else {
            Issue.record("Expected .data message")
        }
    }

    // MARK: - binaryMessages() stream tests

    @Test("binaryMessages() stream finishes on disconnect without yielding")
    func binaryMessagesStreamFinishesOnDisconnect() async {
        let provider = InProcessMockWebSocketProvider()
        let stream = await provider.binaryMessages()
        var iterator = stream.makeAsyncIterator()
        await provider.finish()
        let item = await iterator.next()
        #expect(item == nil)
    }

    @Test("binaryMessages() stream receives injected binary frame")
    func binaryMessagesStreamReceivesBinaryFrame() async {
        let provider = InProcessMockWebSocketProvider()
        let stream = await provider.binaryMessages()
        let payload = Data([0xDE, 0xAD, 0xBE, 0xEF])

        Task {
            await provider.injectBinary(payload)
            await provider.finish()
        }

        var received: [Data] = []
        for await frame in stream {
            received.append(frame)
        }

        #expect(received.count == 1)
        #expect(received.first == payload)
    }

    @Test("binaryMessages() stream does not emit text messages")
    func binaryMessagesStreamIgnoresTextMessages() async {
        let provider = InProcessMockWebSocketProvider()
        let stream = await provider.binaryMessages()

        Task {
            await provider.injectMessage(.text("hello"))
            await provider.finish()
        }

        var received: [Data] = []
        for await frame in stream {
            received.append(frame)
        }

        // Text messages must NOT appear in binaryMessages() stream
        #expect(received.isEmpty)
    }

    @Test("binaryMessages() stream receives multiple binary frames in order")
    func binaryMessagesStreamReceivesFramesInOrder() async {
        let provider = InProcessMockWebSocketProvider()
        let stream = await provider.binaryMessages()
        let frame1 = Data([0x01])
        let frame2 = Data([0x02])
        let frame3 = Data([0x03])

        Task {
            await provider.injectBinary(frame1)
            await provider.injectBinary(frame2)
            await provider.injectBinary(frame3)
            await provider.finish()
        }

        var received: [Data] = []
        for await frame in stream {
            received.append(frame)
        }

        #expect(received == [frame1, frame2, frame3])
    }

    @Test("binaryMessages() and messages() streams are independent consumers")
    func binaryAndMessagesStreamsAreIndependent() async {
        let provider = InProcessMockWebSocketProvider()
        let allMessages = await provider.messages()
        let binStream = await provider.binaryMessages()
        let binPayload = Data([0xCA, 0xFE])

        Task {
            await provider.injectMessage(.text("text-frame"))
            await provider.injectBinary(binPayload)
            await provider.finish()
        }

        var allReceived: [WebSocketMessage] = []
        for await msg in allMessages { allReceived.append(msg) }

        var binReceived: [Data] = []
        for await frame in binStream { binReceived.append(frame) }

        // messages() sees both text and binary wrapped in WebSocketMessage
        #expect(allReceived.count == 2)
        // binaryMessages() sees only binary frames
        #expect(binReceived.count == 1)
        #expect(binReceived.first == binPayload)
    }

    // MARK: - Item 7: dispose()

    @Test("dispose() sets connectionState to disconnected")
    func disposeDisconnectsProvider() async {
        let provider = URLSessionWebSocketProvider()
        await provider.dispose()
        let state = await provider.connectionState
        #expect(state == .disconnected)
    }

    @Test("send text throws after dispose()")
    func sendThrowsAfterDispose() async {
        let provider = URLSessionWebSocketProvider()
        await provider.dispose()
        do {
            try await provider.send(text: "hello")
            Issue.record("Expected error after dispose")
        } catch WebSocketError.notConnected {
            #expect(true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("connect throws after dispose()")
    func connectThrowsAfterDispose() async {
        let provider = URLSessionWebSocketProvider()
        await provider.dispose()
        do {
            try await provider.connect(to: URL(string: "wss://example.com")!)
            Issue.record("Expected error after dispose")
        } catch WebSocketError.notConnected {
            #expect(true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("messages() stream receives mixed text and binary messages in order")
    func messagesStreamReceivesMixedPayloads() async {
        let provider = InProcessMockWebSocketProvider()
        let stream = await provider.messages()

        let binaryPayload = Data([0x10, 0x20])
        Task {
            await provider.injectMessage(.text("first"))
            await provider.injectMessage(.data(binaryPayload))
            await provider.injectMessage(.text("last"))
            await provider.finish()
        }

        var received: [WebSocketMessage] = []
        for await msg in stream {
            received.append(msg)
        }

        #expect(received.count == 3)
        #expect(received[0] == .text("first"))
        #expect(received[1] == .data(binaryPayload))
        #expect(received[2] == .text("last"))
    }
}

// MARK: - InProcessMockWebSocketProvider

/// An actor-based WebSocket provider that injects messages directly into an AsyncStream.
/// Used only in tests to exercise the consumer side of binary and mixed payloads.
actor InProcessMockWebSocketProvider: WebSocketProvider {

    private var continuations: [UUID: AsyncStream<WebSocketMessage>.Continuation] = [:]
    private var binaryContinuations: [UUID: AsyncStream<Data>.Continuation] = [:]
    private var _connectionState: WebSocketConnectionState = .connected

    var connectionState: WebSocketConnectionState { _connectionState }

    func connect(to url: URL) async throws { _connectionState = .connected }

    func disconnect() async {
        _connectionState = .disconnected
        let conts = continuations
        continuations.removeAll()
        conts.values.forEach { $0.finish() }
        let binConts = binaryContinuations
        binaryContinuations.removeAll()
        binConts.values.forEach { $0.finish() }
    }

    func send(text: String) async throws {}
    func send(data: Data) async throws {}

    func messages() -> AsyncStream<WebSocketMessage> {
        AsyncStream { continuation in
            let id = UUID()
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id: id) }
            }
            continuations[id] = continuation
        }
    }

    /// Returns an `AsyncStream` that yields only raw binary frames.
    func binaryMessages() -> AsyncStream<Data> {
        AsyncStream { continuation in
            let id = UUID()
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeBinaryContinuation(id: id) }
            }
            binaryContinuations[id] = continuation
        }
    }

    /// Yields a message to all registered `messages()` consumers.
    /// Binary `.data` frames are also forwarded to `binaryMessages()` consumers.
    func injectMessage(_ message: WebSocketMessage) {
        continuations.values.forEach { $0.yield(message) }
        if case .data(let bytes) = message {
            binaryContinuations.values.forEach { $0.yield(bytes) }
        }
    }

    /// Yields raw binary data directly to `binaryMessages()` consumers
    /// and wraps it in `.data` for `messages()` consumers.
    func injectBinary(_ data: Data) {
        continuations.values.forEach { $0.yield(.data(data)) }
        binaryContinuations.values.forEach { $0.yield(data) }
    }

    /// Finishes all consumer streams.
    func finish() {
        let conts = continuations
        continuations.removeAll()
        conts.values.forEach { $0.finish() }
        let binConts = binaryContinuations
        binaryContinuations.removeAll()
        binConts.values.forEach { $0.finish() }
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func removeBinaryContinuation(id: UUID) {
        binaryContinuations.removeValue(forKey: id)
    }
}
