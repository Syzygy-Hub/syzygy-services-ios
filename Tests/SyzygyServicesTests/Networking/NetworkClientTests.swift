import Testing
import Foundation
@testable import SyzygyServices
import SyzygyFoundation

// MARK: - Mock URLProtocol

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Helpers

private func makeMockClient(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data),
    interceptors: [any RequestInterceptor] = [],
    maxRetries: Int = 0
) -> URLSessionNetworkClient {
    MockURLProtocol.requestHandler = handler
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)
    return URLSessionNetworkClient(session: session, interceptors: interceptors, maxRetries: maxRetries)
}

private func makeResponse(statusCode: Int, body: Data = Data()) -> (HTTPURLResponse, Data) {
    let url = URL(string: "https://example.com")!
    let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    return (response, body)
}

// MARK: - Tests

@Suite("NetworkClient", .serialized)
struct NetworkClientTests {

    @Test("Successful GET returns 200 response with data")
    func successfulGet() async throws {
        let expectedBody = Data("{\"ok\":true}".utf8)
        let client = makeMockClient { _ in makeResponse(statusCode: 200, body: expectedBody) }
        let request = NetworkRequest(url: "https://example.com/api", method: .get)
        let response = try await client.execute(request)
        #expect(response.statusCode == 200)
        #expect(response.data == expectedBody)
        #expect(response.isSuccess)
    }

    @Test("404 response throws NetworkServiceError with notFound code")
    func clientError404() async throws {
        let client = makeMockClient { _ in makeResponse(statusCode: 404) }
        let request = NetworkRequest(url: "https://example.com/missing", method: .get)
        do {
            _ = try await client.execute(request)
            Issue.record("Expected error to be thrown")
        } catch let error as NetworkServiceError {
            #expect(error.code == .notFound)
        }
    }

    @Test("401 response throws unauthenticated error")
    func clientError401() async throws {
        let client = makeMockClient { _ in makeResponse(statusCode: 401) }
        let request = NetworkRequest(url: "https://example.com/secure", method: .get)
        do {
            _ = try await client.execute(request)
            Issue.record("Expected error to be thrown")
        } catch let error as NetworkServiceError {
            #expect(error.code == .unauthenticated)
        }
    }

    @Test("Interceptor adapt is called before request")
    func interceptorAdaptCalled() async throws {
        actor InterceptorSpy: RequestInterceptor {
            var adaptCalled = false
            func adapt(_ request: NetworkRequest) async throws -> NetworkRequest {
                adaptCalled = true
                return request
            }
        }
        let spy = InterceptorSpy()
        let client = makeMockClient(
            handler: { _ in makeResponse(statusCode: 200) },
            interceptors: [spy]
        )
        let request = NetworkRequest(url: "https://example.com", method: .get)
        _ = try await client.execute(request)
        let called = await spy.adaptCalled
        #expect(called)
    }

    @Test("POST request sends correct HTTP method")
    func postRequestMethod() async throws {
        var capturedMethod: String?
        let client = makeMockClient { req in
            capturedMethod = req.httpMethod
            return makeResponse(statusCode: 201, body: Data("{\"id\":1}".utf8))
        }
        let body = Data("{\"name\":\"test\"}".utf8)
        let request = NetworkRequest(url: "https://example.com/items", method: .post, body: body)
        _ = try await client.execute(request)
        #expect(capturedMethod == "POST")
    }

    @Test("Timeout error maps to SyzygyErrorCode.timeout")
    func timeoutMapsCorrectly() async throws {
        let client = makeMockClient { _ in
            throw URLError(.timedOut)
        }
        let request = NetworkRequest(url: "https://example.com", method: .get, timeoutSeconds: 1)
        do {
            _ = try await client.execute(request)
            Issue.record("Expected timeout error")
        } catch let error as NetworkServiceError {
            #expect(error.code == .timeout)
        }
    }
}
