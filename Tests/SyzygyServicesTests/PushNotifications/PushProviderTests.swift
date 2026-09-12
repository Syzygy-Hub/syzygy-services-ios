import Testing
import Foundation
@testable import SyzygyServices

@Suite("PushProvider")
struct PushProviderTests {

    @Test("registerToken stores token as hex string")
    func storesTokenAsHexString() {
        let provider = APNSPushProvider()
        let tokenData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        provider.registerToken(tokenData)
        #expect(provider.deviceTokenString == "deadbeef")
    }

    @Test("deviceTokenString is nil before registration")
    func deviceTokenNilBeforeRegistration() {
        let provider = APNSPushProvider()
        #expect(provider.deviceTokenString == nil)
    }

    @Test("handleNotification invokes registered handler")
    func handlerInvoked() {
        let provider = APNSPushProvider()
        final class Box: @unchecked Sendable { var value: NotificationPayload? }
        let box = Box()
        provider.onNotification { payload in box.value = payload }
        let payload = NotificationPayload(title: "Hello", body: "World", userInfo: ["key": "val"])
        provider.handleNotification(payload)
        #expect(box.value?.title == "Hello")
        #expect(box.value?.body == "World")
        #expect(box.value?.userInfo["key"] == "val")
    }

    @Test("NotificationPayload carries userInfo")
    func notificationPayloadUserInfo() {
        let payload = NotificationPayload(title: "T", body: "B", userInfo: ["action": "open"])
        #expect(payload.userInfo["action"] == "open")
    }

    @Test("Re-registering token updates the stored value")
    func reRegisterUpdatesToken() {
        let provider = APNSPushProvider()
        provider.registerToken(Data([0x01]))
        provider.registerToken(Data([0x02]))
        #expect(provider.deviceTokenString == "02")
    }
}
