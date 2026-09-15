import Testing
import Foundation
@testable import SyzygyServices
import SyzygyFoundation

@Suite("RemoteConfigProvider")
struct RemoteConfigProviderTests {

    @Test("string value round-trips")
    func stringRoundTrip() {
        let provider = InMemoryRemoteConfigProvider(initialValues: ["greeting": "hello"])
        #expect(provider.string(forKey: "greeting") == "hello")
    }

    @Test("bool value round-trips")
    func boolRoundTrip() {
        let provider = InMemoryRemoteConfigProvider(initialValues: ["flag": true])
        #expect(provider.bool(forKey: "flag") == true)
    }

    @Test("int and double value round-trips")
    func numericRoundTrips() {
        let provider = InMemoryRemoteConfigProvider(initialValues: ["count": 7, "ratio": 0.5])
        #expect(provider.int(forKey: "count") == 7)
        #expect(provider.double(forKey: "ratio") == 0.5)
    }

    @Test("missing key returns nil")
    func missingKeyReturnsNil() {
        let provider = InMemoryRemoteConfigProvider()
        #expect(provider.string(forKey: "absent") == nil)
        #expect(provider.bool(forKey: "absent") == nil)
    }

    @Test("lastFetchDate is set after fetch")
    func lastFetchDateSetAfterFetch() async {
        let provider = InMemoryRemoteConfigProvider()
        #expect(provider.lastFetchDate == nil)
        await provider.fetch()
        #expect(provider.lastFetchDate != nil)
    }

    @Test("setValue overrides existing value")
    func setValueOverrides() {
        let provider = InMemoryRemoteConfigProvider(initialValues: ["key": "old"])
        provider.setValue("new", forKey: "key")
        #expect(provider.string(forKey: "key") == "new")
    }

    // MARK: - NetworkedRemoteConfigProvider Cache TTL

    @Test("First fetch hits network and sets lastFetchDate")
    func firstFetchHitsNetworkAndSetsLastFetchDate() async throws {
        let remoteValues = ["feature_flag": "enabled"]
        let data = try JSONSerialization.data(withJSONObject: remoteValues)
        let mockClient = RemoteConfigMockNetworkClient(responseData: data)
        let provider = NetworkedRemoteConfigProvider(
            client: mockClient,
            endpoint: "https://example.com/config",
            cacheTtlSeconds: 3600
        )
        #expect(provider.lastFetchDate == nil)
        await provider.fetch()
        #expect(provider.lastFetchDate != nil)
        #expect(provider.string(forKey: "feature_flag") == "enabled")
        let fetchCount = await mockClient.fetchCount
        #expect(fetchCount == 1)
    }

    @Test("Cache hit: second fetch within TTL does not hit network")
    func cacheHitSecondFetchSkipsNetwork() async throws {
        let remoteValues = ["x": "1"]
        let data = try JSONSerialization.data(withJSONObject: remoteValues)
        let mockClient = RemoteConfigMockNetworkClient(responseData: data)
        let provider = NetworkedRemoteConfigProvider(
            client: mockClient,
            endpoint: "https://example.com/config",
            cacheTtlSeconds: 3600 // very long TTL
        )
        await provider.fetch() // first fetch — hits network
        await provider.fetch() // second fetch — should use cache

        let fetchCount = await mockClient.fetchCount
        #expect(fetchCount == 1) // network called only once
    }

    @Test("Cache miss: fetch after TTL expiry hits network again")
    func cacheMissAfterTTLExpiryHitsNetwork() async throws {
        let remoteValues = ["y": "2"]
        let data = try JSONSerialization.data(withJSONObject: remoteValues)
        let mockClient = RemoteConfigMockNetworkClient(responseData: data)
        let provider = NetworkedRemoteConfigProvider(
            client: mockClient,
            endpoint: "https://example.com/config",
            cacheTtlSeconds: 0 // zero TTL → always stale
        )
        await provider.fetch() // first fetch
        await provider.fetch() // second fetch — TTL already expired

        let fetchCount = await mockClient.fetchCount
        #expect(fetchCount == 2) // network called both times
    }

    @Test("cacheTtlSeconds default is 3600")
    func defaultCacheTtlIs3600() {
        let mockClient = RemoteConfigMockNetworkClient(responseData: Data())
        let provider = NetworkedRemoteConfigProvider(
            client: mockClient,
            endpoint: "https://example.com/config"
        )
        #expect(provider.cacheTtlSeconds == 3600)
    }
}

// MARK: - RemoteConfigMockNetworkClient

/// A simple actor-based mock network client for remote config tests.
actor RemoteConfigMockNetworkClient: NetworkClientProtocol {
    private(set) var fetchCount = 0
    private let responseData: Data

    init(responseData: Data) {
        self.responseData = responseData
    }

    func execute(_ request: NetworkRequest) async throws -> NetworkResponse {
        fetchCount += 1
        return NetworkResponse(statusCode: 200, data: responseData, headers: [:])
    }
}
