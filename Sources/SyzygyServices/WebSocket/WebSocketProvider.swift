import Foundation
import SyzygyFoundation

// MARK: - WebSocketConnectionState

/// The connection state of a WebSocket.
public enum WebSocketConnectionState: Equatable, Sendable {
    /// Not connected.
    case disconnected
    /// Connection is being established.
    case connecting
    /// Connection is active.
    case connected
}

// MARK: - WebSocketMessage

/// A message received from a WebSocket connection.
public enum WebSocketMessage: Sendable {
    /// A UTF-8 text message.
    case text(String)
    /// A binary data message.
    case data(Data)
}

// MARK: - WebSocketProvider Protocol

/// Defines the contract for WebSocket connectivity.
public protocol WebSocketProvider: Sendable {
    /// The current connection state.
    var connectionState: WebSocketConnectionState { get async }
    /// Opens a WebSocket connection to the given URL.
    func connect(to url: URL) async throws
    /// Closes the connection.
    func disconnect() async
    /// Sends a UTF-8 text message.
    func send(text: String) async throws
    /// Sends a binary data message.
    func send(data: Data) async throws
    /// Returns an `AsyncStream` of incoming messages. Yields until disconnected.
    func messages() async -> AsyncStream<WebSocketMessage>
}

// MARK: - Errors

/// Errors produced by `URLSessionWebSocketProvider`.
public enum WebSocketError: Error, Sendable {
    /// An operation was attempted on a disconnected socket.
    case notConnected
    /// An unknown message type was received from the underlying transport.
    case unknownMessageType
}

// MARK: - URLSessionWebSocketProvider

/// A `WebSocketProvider` backed by `URLSessionWebSocketTask` with reconnection support.
public actor URLSessionWebSocketProvider: WebSocketProvider {

    private let session: URLSession
    private let maxReconnectAttempts: Int
    private var task: URLSessionWebSocketTask?
    private var _connectionState: WebSocketConnectionState = .disconnected
    private var continuations: [UUID: AsyncStream<WebSocketMessage>.Continuation] = [:]
    private var currentURL: URL?

    /// Initialises the provider.
    /// - Parameters:
    ///   - session: The URLSession to use.
    ///   - maxReconnectAttempts: Maximum automatic reconnect attempts (default 3).
    public init(session: URLSession = .shared, maxReconnectAttempts: Int = 3) {
        self.session = session
        self.maxReconnectAttempts = maxReconnectAttempts
    }

    /// The current connection state.
    public var connectionState: WebSocketConnectionState { _connectionState }

    public func connect(to url: URL) async throws {
        _connectionState = .connecting
        currentURL = url
        task = session.webSocketTask(with: url)
        task?.resume()
        _connectionState = .connected
        startReceiving()
    }

    public func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        _connectionState = .disconnected
        let conts = continuations
        continuations.removeAll()
        for cont in conts.values { cont.finish() }
    }

    public func send(text: String) async throws {
        guard let task, _connectionState == .connected else { throw WebSocketError.notConnected }
        try await task.send(.string(text))
    }

    public func send(data: Data) async throws {
        guard let task, _connectionState == .connected else { throw WebSocketError.notConnected }
        try await task.send(.data(data))
    }

    public func messages() -> AsyncStream<WebSocketMessage> {
        AsyncStream { continuation in
            let id = UUID()
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id: id) }
            }
            self.continuations[id] = continuation
        }
    }

    // MARK: - Private

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func startReceiving() {
        Task {
            await receiveLoop(attempt: 0)
        }
    }

    private func receiveLoop(attempt: Int) async {
        guard let task, _connectionState == .connected else { return }
        do {
            let message = try await task.receive()
            let wsMessage: WebSocketMessage
            switch message {
            case .string(let text): wsMessage = .text(text)
            case .data(let data): wsMessage = .data(data)
            @unknown default:
                await receiveLoop(attempt: 0)
                return
            }
            for cont in continuations.values { cont.yield(wsMessage) }
            await receiveLoop(attempt: 0)
        } catch {
            if attempt < maxReconnectAttempts, let url = currentURL {
                let delay = pow(2.0, Double(attempt))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                _connectionState = .connecting
                let newTask = session.webSocketTask(with: url)
                self.task = newTask
                newTask.resume()
                _connectionState = .connected
                await receiveLoop(attempt: attempt + 1)
            } else {
                _connectionState = .disconnected
                let conts = continuations
                continuations.removeAll()
                for cont in conts.values { cont.finish() }
            }
        }
    }
}
