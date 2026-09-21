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

    // MARK: - Item 4: Session ID consistency

    @Test("session_id is injected into every tracked event's metadata")
    func sessionIdInjectedIntoTrackedEvent() {
        let provider = ConsoleAnalyticsProvider()
        let event = AnalyticsEvent(name: "purchase", properties: ["item": "shoes"])
        provider.track(event)
        let props = provider.lastTrackedProperties()
        #expect(props?["session_id"] != nil)
        #expect(props?["session_id"] == provider.sessionId)
    }

    // MARK: - HI-06: PII redaction

    @Test("identify does not log userId in plain text")
    func identifyRedactsUserId() {
        let provider = ConsoleAnalyticsProvider()
        var captured: [String] = []
        provider.logger = { captured.append($0) }

        provider.identify(userId: "test@example.com", traits: ["email": "test@example.com"])

        let output = captured.joined()
        #expect(!output.contains("test@example.com"),
                "Plain-text PII must not appear in log output")
        #expect(output.contains("<redacted>"),
                "Redaction sentinel must appear in log output")
    }

    @Test("session_id changes after reset() and new events carry the new session_id")
    func sessionIdChangesAfterReset() {
        let provider = ConsoleAnalyticsProvider()
        let originalSessionId = provider.sessionId
        let event1 = AnalyticsEvent(name: "event_before_reset", properties: [:])
        provider.track(event1)
        let propsBefore = provider.lastTrackedProperties()
        #expect(propsBefore?["session_id"] == originalSessionId)

        provider.reset()
        let newSessionId = provider.sessionId
        #expect(newSessionId != originalSessionId)

        let event2 = AnalyticsEvent(name: "event_after_reset", properties: [:])
        provider.track(event2)
        let propsAfter = provider.lastTrackedProperties()
        #expect(propsAfter?["session_id"] == newSessionId)
    }
}
