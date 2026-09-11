import Testing
@testable import SyzygyServices

@Suite("AnalyticsProvider")
struct AnalyticsProviderTests {
    @Test("ConsoleAnalyticsProvider tracks event without throwing")
    func tracksEventWithoutThrowing() {
        let provider = ConsoleAnalyticsProvider()
        provider.track(event: "test_event", properties: ["key": "value"])
        // If we reach here the call completed successfully.
        #expect(Bool(true))
    }
}
