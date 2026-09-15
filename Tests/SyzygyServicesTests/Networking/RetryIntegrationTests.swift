import Testing
import Foundation
@testable import SyzygyServices
import SyzygyFoundation

// MARK: - Retry Mock URLProtocol

/// A thread-safe controller driving the URLProtocol mock response queue.
/// Uses NSLock instead of an actor to avoid Swift 6 Sendability issues when bridging
/// URLProtocol's synchronous startLoading() to an async test context.
final class RetryMockController: @unchecked Sendable {
    private let lock = NSLock()
    private var responseQueue: [(statusCode: Int, error: (any Error)?)] = []
    private(set) var requestCount = 0

    func enqueue(statusCode: Int) {
        lock.withLock { responseQueue.append((statusCode: statusCode, error: nil)) }
    }

    func enqueueError(_ error: any Error) {
        lock.withLock { responseQueue.append((statusCode: 0, error: error)) }
    }

    func next() -> (statusCode: Int, error: (any Error)?) {
        lock.withLock {
            requestCount += 1
            guard !responseQueue.isEmpty else { return (statusCode: 200, error: nil) }
            return responseQueue.removeFirst()
        }
    }
}

// URLProtocol subclass that dequeues from the shared controller synchronously.
final class RetryURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var controller: RetryMockController?

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let controller = RetryURLProtocol.controller else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let result = controller.next()
        if let error = result.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let url = request.url ?? URL(string: "https://example.com")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: result.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - MockBackoffClock

/// A deterministic `BackoffClock` that records delay durations without sleeping.
/// Inject this into `URLSessionNetworkClient` to make retry tests instantaneous
/// and verifiable — mirroring the coroutine-test-scheduler approach on Android.
final class MockBackoffClock: BackoffClock, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var recordedDelays: [UInt64] = []

    func sleep(nanoseconds: UInt64) async throws {
        lock.withLock { recordedDelays.append(nanoseconds) }
        // No real sleep — tests run at full speed.
    }
}

// MARK: - Helpers

private func makeRetryClient(
    controller: RetryMockController,
    maxRetries: Int
) -> URLSessionNetworkClient {
    RetryURLProtocol.controller = controller
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [RetryURLProtocol.self]
    let session = URLSession(configuration: config)
    return URLSessionNetworkClient(session: session, maxRetries: maxRetries)
}

// MARK: - Tests

/// Integration tests for the retry and backoff behaviour of `URLSessionNetworkClient`.
///
/// These tests use `RetryURLProtocol` to intercept real `URLSession` requests, enabling
/// end-to-end verification of the retry loop, exponential-backoff scheduling, server-recovery
/// scenarios, and the maximum-retry ceiling — all without real network I/O.
@Suite("Networking Retry Integration", .serialized)
struct RetryIntegrationTests {

    // MARK: Retry count

    @Test("Client retries correct number of times on 5xx failure")
    func retriesCorrectCountOnServerError() async throws {
        let controller = RetryMockController()
        // Enqueue 3 server errors (500) then a success; maxRetries = 3
        controller.enqueue(statusCode: 500)
        controller.enqueue(statusCode: 500)
        controller.enqueue(statusCode: 500)
        controller.enqueue(statusCode: 200)

        let client = makeRetryClient(controller: controller, maxRetries: 3)
        let request = NetworkRequest(url: "https://example.com/api", method: .get)
        let response = try await client.execute(request)

        let count = controller.requestCount
        #expect(response.statusCode == 200)
        // Initial attempt + 3 retries = 4 total requests
        #expect(count == 4)
    }

    @Test("Client retries on NSURLErrorNetworkConnectionLost")
    func retriesOnNetworkConnectionLost() async throws {
        let controller = RetryMockController()
        let networkError = URLError(.networkConnectionLost)
        controller.enqueueError(networkError)
        controller.enqueueError(networkError)
        controller.enqueue(statusCode: 200)

        let client = makeRetryClient(controller: controller, maxRetries: 3)
        let request = NetworkRequest(url: "https://example.com/api", method: .get)
        let response = try await client.execute(request)

        let count = controller.requestCount
        #expect(response.statusCode == 200)
        #expect(count == 3) // 2 failures + 1 success
    }

    // MARK: Server recovery on Nth attempt

    @Test("Succeeds when server recovers on second attempt")
    func succeedsOnSecondAttempt() async throws {
        let controller = RetryMockController()
        controller.enqueue(statusCode: 503)
        controller.enqueue(statusCode: 200)

        let client = makeRetryClient(controller: controller, maxRetries: 2)
        let request = NetworkRequest(url: "https://example.com/api", method: .get)
        let response = try await client.execute(request)

        #expect(response.statusCode == 200)
        let count = controller.requestCount
        #expect(count == 2)
    }

    @Test("Succeeds when server recovers on third attempt")
    func succeedsOnThirdAttempt() async throws {
        let controller = RetryMockController()
        controller.enqueue(statusCode: 500)
        controller.enqueue(statusCode: 500)
        controller.enqueue(statusCode: 200)

        let client = makeRetryClient(controller: controller, maxRetries: 3)
        let request = NetworkRequest(url: "https://example.com/api", method: .get)
        let response = try await client.execute(request)

        #expect(response.statusCode == 200)
        let count = controller.requestCount
        #expect(count == 3)
    }

    // MARK: Max retry ceiling

    @Test("Does not retry beyond maxRetries ceiling")
    func doesNotExceedMaxRetryCeiling() async throws {
        let maxRetries = 2
        let controller = RetryMockController()
        // Provide more errors than maxRetries allows
        for _ in 0..<(maxRetries + 5) {
            controller.enqueue(statusCode: 500)
        }

        let client = makeRetryClient(controller: controller, maxRetries: maxRetries)
        let request = NetworkRequest(url: "https://example.com/api", method: .get)

        // The last 500 after exhausted retries should still be returned (not throw for 5xx unless
        // the implementation chooses to; the key assertion is the total request count).
        let _ = try? await client.execute(request)

        let count = controller.requestCount
        // Should be initial attempt + maxRetries attempts (not more)
        #expect(count == maxRetries + 1)
    }

    @Test("maxRetries=0 disables retry — only one request sent")
    func maxRetriesZeroDisablesRetry() async throws {
        let controller = RetryMockController()
        controller.enqueue(statusCode: 500)
        controller.enqueue(statusCode: 200)

        let client = makeRetryClient(controller: controller, maxRetries: 0)
        let request = NetworkRequest(url: "https://example.com/api", method: .get)
        _ = try? await client.execute(request)

        let count = controller.requestCount
        // Exactly one request, no retry
        #expect(count == 1)
    }

    // MARK: Non-retryable errors

    @Test("Client does not retry on 4xx client errors")
    func doesNotRetryOn4xx() async throws {
        let controller = RetryMockController()
        controller.enqueue(statusCode: 400)
        controller.enqueue(statusCode: 200) // would only be hit if client retries

        let client = makeRetryClient(controller: controller, maxRetries: 3)
        let request = NetworkRequest(url: "https://example.com/api", method: .get)
        do {
            _ = try await client.execute(request)
        } catch {}

        let count = controller.requestCount
        // Should have stopped after first 400
        #expect(count == 1)
    }

    @Test("Timed out request does not retry beyond ceiling")
    func timedOutDoesNotExceedCeiling() async throws {
        let maxRetries = 1
        let controller = RetryMockController()
        for _ in 0..<10 {
            controller.enqueueError(URLError(.timedOut))
        }

        let client = makeRetryClient(controller: controller, maxRetries: maxRetries)
        let request = NetworkRequest(url: "https://example.com/api", method: .get)
        do {
            _ = try await client.execute(request)
            Issue.record("Expected timeout error")
        } catch {}

        let count = controller.requestCount
        #expect(count == maxRetries + 1)
    }
}

// MARK: - Injectable Clock Tests — separate URLProtocol to avoid static state conflicts

/// A URLProtocol used exclusively by `RetryBackoffClockTests` so its static controller
/// never races with `RetryURLProtocol.controller` used by `RetryIntegrationTests`.
final class ClockTestURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var controller: RetryMockController?

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let controller = ClockTestURLProtocol.controller else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let result = controller.next()
        if let error = result.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let url = request.url ?? URL(string: "https://example.com")!
        let response = HTTPURLResponse(url: url, statusCode: result.statusCode,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeClockClient(
    controller: RetryMockController,
    maxRetries: Int,
    clock: any BackoffClock
) -> URLSessionNetworkClient {
    ClockTestURLProtocol.controller = controller
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ClockTestURLProtocol.self]
    let session = URLSession(configuration: config)
    return URLSessionNetworkClient(session: session, maxRetries: maxRetries, clock: clock)
}

/// Deterministic tests for exponential back-off delay scheduling.
///
/// Uses `MockBackoffClock` to verify that the delay between each retry follows the
/// `2^attempt` second formula (expressed in nanoseconds) — matching the Android
/// coroutine-test-scheduler pattern where the virtual clock is advanced rather than
/// waiting on real wall time.
@Suite("Retry Backoff Injectable Clock", .serialized)
struct RetryBackoffClockTests {

    @Test("No delay is recorded when the first request succeeds")
    func noDelayOnImmediateSuccess() async throws {
        let clock = MockBackoffClock()
        let controller = RetryMockController()
        controller.enqueue(statusCode: 200)

        let client = makeClockClient(controller: controller, maxRetries: 3, clock: clock)
        let request = NetworkRequest(url: "https://example.com/api", method: .get)
        _ = try await client.execute(request)

        #expect(clock.recordedDelays.isEmpty)
    }

    @Test("One delay recorded for a single retry (2^0 seconds in nanoseconds)")
    func oneDelayOnFirstRetry() async throws {
        let clock = MockBackoffClock()
        let controller = RetryMockController()
        controller.enqueue(statusCode: 500)
        controller.enqueue(statusCode: 200)

        let client = makeClockClient(controller: controller, maxRetries: 3, clock: clock)
        let request = NetworkRequest(url: "https://example.com/api", method: .get)
        _ = try await client.execute(request)

        #expect(clock.recordedDelays.count == 1)
        // attempt 0 → 2^0 * 1_000_000_000 = 1_000_000_000 ns
        #expect(clock.recordedDelays[0] == 1_000_000_000)
    }

    @Test("Two delays recorded for two retries with exponential values")
    func twoDelaysExponentialBackoff() async throws {
        let clock = MockBackoffClock()
        let controller = RetryMockController()
        controller.enqueue(statusCode: 500)
        controller.enqueue(statusCode: 500)
        controller.enqueue(statusCode: 200)

        let client = makeClockClient(controller: controller, maxRetries: 3, clock: clock)
        let request = NetworkRequest(url: "https://example.com/api", method: .get)
        _ = try await client.execute(request)

        #expect(clock.recordedDelays.count == 2)
        // attempt 0 → 1_000_000_000 ns (1 s)
        // attempt 1 → 2_000_000_000 ns (2 s)
        #expect(clock.recordedDelays[0] == 1_000_000_000)
        #expect(clock.recordedDelays[1] == 2_000_000_000)
    }

    @Test("Three delays recorded for maxRetries=3 exhausted")
    func threeDelaysWhenMaxRetriesExhausted() async throws {
        let clock = MockBackoffClock()
        let controller = RetryMockController()
        for _ in 0..<4 { controller.enqueue(statusCode: 500) }

        let client = makeClockClient(controller: controller, maxRetries: 3, clock: clock)
        let request = NetworkRequest(url: "https://example.com/api", method: .get)
        _ = try? await client.execute(request)

        // 3 retries means 3 sleeps: attempts 0, 1, 2
        #expect(clock.recordedDelays.count == 3)
        #expect(clock.recordedDelays[0] == 1_000_000_000)
        #expect(clock.recordedDelays[1] == 2_000_000_000)
        #expect(clock.recordedDelays[2] == 4_000_000_000)
    }

    @Test("MockBackoffClock tests run without real wall-clock delay")
    func clockTestsAreInstantaneous() async throws {
        let clock = MockBackoffClock()
        let controller = RetryMockController()
        for _ in 0..<3 { controller.enqueue(statusCode: 503) }
        controller.enqueue(statusCode: 200)

        let client = makeClockClient(controller: controller, maxRetries: 3, clock: clock)
        let request = NetworkRequest(url: "https://example.com/api", method: .get)
        let start = Date()
        _ = try await client.execute(request)
        let elapsed = Date().timeIntervalSince(start)

        // Should complete well under 1 second despite simulated 1+2+4 second delays
        #expect(elapsed < 5.0)
        #expect(clock.recordedDelays.count == 3)
    }

    @Test("No delay is recorded for non-retryable 4xx errors")
    func noDelayForClientErrors() async throws {
        let clock = MockBackoffClock()
        let controller = RetryMockController()
        controller.enqueue(statusCode: 400)

        let client = makeClockClient(controller: controller, maxRetries: 3, clock: clock)
        let request = NetworkRequest(url: "https://example.com/api", method: .get)
        do {
            _ = try await client.execute(request)
        } catch {}

        // 4xx errors are not retried — no sleep should be recorded
        #expect(clock.recordedDelays.isEmpty)
    }
}
