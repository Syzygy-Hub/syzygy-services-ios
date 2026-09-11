import Foundation
import SyzygyFoundation

// MARK: - Protocol

/// Defines the contract for performing HTTP network requests.
public protocol NetworkClient: Sendable {
    /// Performs an async HTTP GET request and returns decoded data.
    func get<T: Decodable>(_ url: URL) async throws -> T
    /// Performs an async HTTP POST request with an encodable body.
    func post<T: Decodable, U: Encodable>(_ url: URL, body: U) async throws -> T
}

// MARK: - URLSession Implementation

/// A `NetworkClient` backed by `URLSession` with async/await support.
public final class URLSessionNetworkClient: NetworkClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    /// Initialises the client with a given `URLSession` and `JSONDecoder`.
    public init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    public func get<T: Decodable>(_ url: URL) async throws -> T {
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(T.self, from: data)
    }

    public func post<T: Decodable, U: Encodable>(_ url: URL, body: U) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await session.data(for: request)
        return try decoder.decode(T.self, from: data)
    }
}
