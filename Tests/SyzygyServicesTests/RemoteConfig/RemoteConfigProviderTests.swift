import Testing
@testable import SyzygyServices

@Suite("RemoteConfigProvider")
struct RemoteConfigProviderTests {
    @Test("InMemoryRemoteConfigProvider round-trips string and bool")
    func roundTripsValues() {
        let provider = InMemoryRemoteConfigProvider()
        provider.setValue("world", forKey: "greeting")
        provider.setValue(true, forKey: "flag")
        #expect(provider.string(forKey: "greeting") == "world")
        #expect(provider.bool(forKey: "flag") == true)
        #expect(provider.string(forKey: "missing") == nil)
    }
}
