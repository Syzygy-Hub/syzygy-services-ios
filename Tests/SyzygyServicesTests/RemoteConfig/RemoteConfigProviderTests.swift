import Testing
import Foundation
@testable import SyzygyServices

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
}
