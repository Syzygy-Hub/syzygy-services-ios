import Testing
import Foundation
@testable import SyzygyServices

@Suite("PushProvider")
struct PushProviderTests {
    @Test("APNSPushProvider stores token as hex string")
    func storesTokenAsHexString() {
        let provider = APNSPushProvider()
        let tokenData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        provider.registerToken(tokenData)
        #expect(provider.deviceTokenString == "deadbeef")
    }
}
