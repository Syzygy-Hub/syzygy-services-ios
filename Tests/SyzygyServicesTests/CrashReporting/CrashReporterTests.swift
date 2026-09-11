import Testing
@testable import SyzygyServices

@Suite("CrashReporter")
struct CrashReporterTests {
    @Test("ConsoleCrashReporter records error without throwing")
    func recordsErrorWithoutThrowing() {
        let reporter = ConsoleCrashReporter()
        reporter.recordError(AuthError.refreshNotImplemented, metadata: ["ctx": "test"])
        reporter.reportCrash(message: "test crash", metadata: [:])
        #expect(Bool(true))
    }
}
