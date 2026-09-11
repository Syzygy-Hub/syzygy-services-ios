import Testing
@testable import SyzygyServices

@Suite("DeviceProvider")
struct DeviceProviderTests {
    @Test("PlatformDeviceProvider returns non-empty system name")
    func returnsNonEmptySystemName() {
        let provider = PlatformDeviceProvider()
        #expect(!provider.systemName.isEmpty)
        #expect(!provider.systemVersion.isEmpty)
    }
}
