import Foundation
import SyzygyFoundation

// MARK: - Protocol

/// Defines the contract for WebSocket connectivity.
public protocol WebSocketProvider: Sendable {
    /// Opens a WebSocket connection to the given URL.
    func connect(to url: URL) async throws
    /// Sends a text message over the connection.
    func send(text: String) async throws
    /// Receives the next message from the connection.
    func receive() async throws -> String
    /// Closes the connection.
    func disconnect()
}

// MARK: - URLSession Stub Implementation

/// A `WebSocketProvider` backed by `URLSessionWebSocketTask`.
public final class URLSessionWebSocketProvider: NSObject, WebSocketProvider {
    nonisolated(unsafe) private var task: URLSessionWebSocketTask?
    private let session: URLSession

    /// Initialises the provider with a given `URLSession`.
    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func connect(to url: URL) async throws {
        task = session.webSocketTask(with: url)
        task?.resume()
    }

    public func send(text: String) async throws {
        guard let task else { throw WebSocketError.notConnected }
        try await task.send(.string(text))
    }

    public func receive() async throws -> String {
        guard let task else { throw WebSocketError.notConnected }
        let message = try await task.receive()
        switch message {
        case .string(let text): return text
        case .data(let data): return String(decoding: data, as: UTF8.self)
        @unknown default: throw WebSocketError.unknownMessageType
        }
    }

    public func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }
}

/// Errors thrown by `URLSessionWebSocketProvider`.
public enum WebSocketError: Error {
    /// The WebSocket is not connected.
    case notConnected
    /// An unknown message type was received.
    case unknownMessageType
}
