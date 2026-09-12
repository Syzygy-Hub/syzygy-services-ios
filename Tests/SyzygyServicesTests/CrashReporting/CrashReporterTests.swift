import Testing
import Foundation
@testable import SyzygyServices

@Suite("CrashReporter")
struct CrashReporterTests {

    @Test("recordError logs without throwing")
    func recordErrorDoesNotThrow() {
        let reporter = ConsoleCrashReporter()
        struct TestError: Error {}
        reporter.recordError(TestError(), metadata: ["ctx": "test"])
        #expect(true)
    }

    @Test("reportCrash stubs without terminating process")
    func reportCrashIsStubbed() {
        let reporter = ConsoleCrashReporter()
        reporter.reportCrash(message: "test crash", metadata: ["reason": "test"])
        #expect(true)
    }

    @Test("setMetadata stores key-value pair")
    func setMetadataStores() {
        let reporter = ConsoleCrashReporter()
        reporter.setMetadata(key: "environment", value: "staging")
        reporter.setMetadata(key: "version", value: "1.2.3")
        let meta = reporter.currentMetadata()
        #expect(meta["environment"] == "staging")
        #expect(meta["version"] == "1.2.3")
    }

    @Test("setUserContext stores userId and email")
    func setUserContextStores() {
        let reporter = ConsoleCrashReporter()
        reporter.setUserContext(userId: "user-99", email: "test@example.com")
        let ctx = reporter.currentUserContext()
        #expect(ctx?.userId == "user-99")
        #expect(ctx?.email == "test@example.com")
    }

    @Test("userContext is nil before setUserContext")
    func userContextNilInitially() {
        let reporter = ConsoleCrashReporter()
        #expect(reporter.currentUserContext() == nil)
    }
}
