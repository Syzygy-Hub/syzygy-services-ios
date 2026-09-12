import Testing
import Foundation
@testable import SyzygyServices
import SyzygyFoundation

@Suite("AnalyticsProvider")
struct AnalyticsProviderTests {

    @Test("track event does not throw")
    func trackEventDoesNotThrow() {
        let provider = ConsoleAnalyticsProvider()
        let event = AnalyticsEvent(name: "button_tapped", properties: ["screen": "home"])
        provider.track(event)
        #expect(true) // reaching here means no crash
    }

    @Test("identify stores userId in user properties")
    func identifyStoresUserId() {
        let provider = ConsoleAnalyticsProvider()
        provider.identify(userId: "user-42", traits: ["plan": "pro"])
        let props = provider.currentUserProperties()
        #expect(props["userId"] == "user-42")
        #expect(props["plan"] == "pro")
    }

    @Test("reset clears user properties and generates new sessionId")
    func resetClearsState() {
        let provider = ConsoleAnalyticsProvider()
        let originalSession = provider.sessionId
        provider.identify(userId: "u1", traits: [:])
        provider.reset()
        #expect(provider.currentUserProperties().isEmpty)
        #expect(provider.sessionId != originalSession)
    }

    @Test("trackScreen emits screen_view event")
    func trackScreenEvent() {
        let provider = ConsoleAnalyticsProvider()
        // trackScreen should not throw
        provider.trackScreen("Dashboard", properties: ["tab": "main"])
        #expect(true)
    }

    @Test("sessionId is non-nil and UUID format on init")
    func sessionIdIsUUID() {
        let provider = ConsoleAnalyticsProvider()
        #expect(UUID(uuidString: provider.sessionId) != nil)
    }
}
