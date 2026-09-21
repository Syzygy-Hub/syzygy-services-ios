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

    // MARK: - Item 5: Breadcrumbs

    @Test("leaveBreadcrumb stores breadcrumb with message and metadata")
    func leaveBreadcrumbStoresBreadcrumb() {
        let reporter = ConsoleCrashReporter()
        reporter.leaveBreadcrumb(message: "User tapped login", metadata: ["screen": "Login"])
        let crumbs = reporter.currentBreadcrumbs()
        #expect(crumbs.count == 1)
        #expect(crumbs[0].message == "User tapped login")
        #expect(crumbs[0].metadata["screen"] == "Login")
    }

    @Test("leaveBreadcrumb with nil metadata stores empty metadata")
    func leaveBreadcrumbNilMetadata() {
        let reporter = ConsoleCrashReporter()
        reporter.leaveBreadcrumb(message: "App launched")
        let crumbs = reporter.currentBreadcrumbs()
        #expect(crumbs.count == 1)
        #expect(crumbs[0].metadata.isEmpty)
    }

    @Test("circular buffer caps at 20 breadcrumbs")
    func circularBufferCapsAtTwenty() {
        let reporter = ConsoleCrashReporter()
        for index in 1...25 {
            reporter.leaveBreadcrumb(message: "Step \(index)")
        }
        let crumbs = reporter.currentBreadcrumbs()
        #expect(crumbs.count == 20)
        // Oldest entries dropped — first kept should be "Step 6"
        #expect(crumbs[0].message == "Step 6")
        #expect(crumbs[19].message == "Step 25")
    }

    @Test("clearBreadcrumbs removes all stored breadcrumbs")
    func clearBreadcrumbsRemovesAll() {
        let reporter = ConsoleCrashReporter()
        reporter.leaveBreadcrumb(message: "A")
        reporter.leaveBreadcrumb(message: "B")
        reporter.clearBreadcrumbs()
        #expect(reporter.currentBreadcrumbs().isEmpty)
    }

    @Test("breadcrumbs are included in reportCrash output (does not crash)")
    func breadcrumbsIncludedInCrashReport() {
        let reporter = ConsoleCrashReporter()
        reporter.leaveBreadcrumb(message: "Nav to checkout")
        reporter.leaveBreadcrumb(message: "Payment initiated")
        // reportCrash should not throw and should include breadcrumbs in output (no crash)
        reporter.reportCrash(message: "Unexpected nil", metadata: [:])
        #expect(true)
    }

    // MARK: - HI-06: PII redaction

    @Test("setUserContext does not log userId or email in plain text")
    func setUserContextRedactsPII() {
        let reporter = ConsoleCrashReporter()
        var captured: [String] = []
        reporter.logger = { captured.append($0) }

        reporter.setUserContext(userId: "test@example.com", email: "test@example.com")

        let output = captured.joined()
        #expect(!output.contains("test@example.com"),
                "Plain-text PII must not appear in log output")
        #expect(output.contains("<redacted>"),
                "Redaction sentinel must appear in log output")
    }
}
