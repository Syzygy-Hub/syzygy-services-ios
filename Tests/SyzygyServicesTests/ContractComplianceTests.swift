import Testing
import Foundation
import Combine
@testable import SyzygyServices
import SyzygyFoundation

/// Contract compliance tests — verify that every concrete service type:
///   1. Can be instantiated without crashing.
///   2. Conforms to the expected Foundation protocol at compile time (the protocol constraint
///      on the `let` binding acts as a compile-time assertion).
///   3. Has its primary method callable and returning the expected type at runtime.
@Suite("Contract Compliance")
struct ContractComplianceTests {

    // MARK: - Networking

    @Test("URLSessionNetworkClient conforms to NetworkClientProtocol and can be instantiated")
    func networkClientConformance() {
        let client: any NetworkClientProtocol = URLSessionNetworkClient()
        // Verify the instance exists and is the right concrete type
        #expect(client is URLSessionNetworkClient)
    }

    // MARK: - Persistence

    @Test("UserDefaultsStorageProvider conforms to StorageProvider and round-trips a value")
    func userDefaultsStorageProviderConformance() {
        let provider: any SyzygyFoundation.StorageProvider = UserDefaultsStorageProvider(
            defaults: UserDefaults(suiteName: "com.test.contract.\(UUID().uuidString)") ?? .standard
        )
        #expect(provider is UserDefaultsStorageProvider)
        let key = StorageKey<String>(identifier: "compliance_test")
        provider.set("hello", for: key)
        #expect(provider.get(key) == "hello")
        provider.remove(key)
        #expect(provider.get(key) == nil)
    }

    @Test("KeychainStorageProvider conforms to StorageProvider and can be instantiated")
    func keychainStorageProviderConformance() {
        let provider: any SyzygyFoundation.StorageProvider = KeychainStorageProvider(
            service: "com.test.contract.keychain.\(UUID().uuidString)"
        )
        #expect(provider is KeychainStorageProvider)
        // Primary capability: set and retrieve a value
        let key = StorageKey<String>(identifier: "keychain_compliance")
        provider.set("secret", for: key)
        #expect(provider.get(key) == "secret")
        provider.remove(key)
    }

    // MARK: - Auth

    @Test("SyzygyAuthProvider conforms to AuthProvider protocol and can be instantiated")
    func authProviderConformance() {
        let provider: any SyzygyFoundation.AuthProvider = SyzygyAuthProvider(
            storage: KeychainStorageProvider(service: "com.test.contract.auth.\(UUID().uuidString)")
        )
        #expect(provider is SyzygyAuthProvider)
        // Primary state access
        #expect(provider.state == .unauthenticated)
        // statePublisher returns AnyPublisher<AuthState, Never>
        let _: AnyPublisher<AuthState, Never> = provider.statePublisher
    }

    // MARK: - File Management

    @Test("FileManagerFileProvider conforms to FileProvider and temporaryDirectory is non-empty")
    func fileProviderConformance() {
        let provider: any FileProvider = FileManagerFileProvider()
        #expect(provider is FileManagerFileProvider)
        // Primary capability: temporaryDirectory returns a non-empty URL
        let tmp = provider.temporaryDirectory
        #expect(!tmp.path.isEmpty)
        // exists(at:) returns Bool
        let doesExist: Bool = provider.exists(at: tmp)
        #expect(doesExist) // temp directory always exists
    }

    // MARK: - Push Notifications

    @Test("APNSPushProvider conforms to PushProvider and deviceTokenString is nil before registration")
    func pushProviderConformance() {
        let provider: any PushProvider = APNSPushProvider()
        #expect(provider is APNSPushProvider)
        // deviceTokenString is nil before a token is registered
        #expect(provider.deviceTokenString == nil)
    }

    @Test("NotificationPayload.makeAlert returns correct title and body")
    func notificationPayloadAlertFactory() {
        let payload = NotificationPayload.makeAlert(title: "Hello", body: "World", userInfo: ["k": "v"])
        #expect(payload.title == "Hello")
        #expect(payload.body == "World")
        #expect(payload.userInfo["k"] == "v")
    }

    @Test("NotificationPayload.makeBackground sets action in userInfo and empty title/body")
    func notificationPayloadBackgroundFactory() {
        let payload = NotificationPayload.makeBackground(action: "sync", userInfo: ["extra": "data"])
        #expect(payload.title.isEmpty)
        #expect(payload.body.isEmpty)
        #expect(payload.userInfo["action"] == "sync")
        #expect(payload.userInfo["extra"] == "data")
    }

    @Test("NotificationPayload.makeBadge stores count in userInfo")
    func notificationPayloadBadgeFactory() {
        let payload = NotificationPayload.makeBadge(count: 7)
        #expect(payload.userInfo["badge"] == "7")
    }

    // MARK: - Device Services

    @Test("PlatformDeviceProvider conforms to DeviceProvider and primary properties are non-empty")
    func deviceProviderConformance() {
        let provider: any DeviceProvider = PlatformDeviceProvider(
            storage: KeychainStorageProvider(service: "com.test.contract.device.\(UUID().uuidString)")
        )
        #expect(provider is PlatformDeviceProvider)
        #expect(!provider.deviceId.isEmpty)
        #expect(!provider.platform.isEmpty)
        #expect(!provider.osVersion.isEmpty)
    }

    // MARK: - Remote Config

    @Test("NetworkedRemoteConfigProvider conforms to RemoteConfigProvider and can be instantiated")
    func networkedRemoteConfigConformance() {
        let mockClient = ContractComplianceMockNetworkClient()
        let provider: any RemoteConfigProvider = NetworkedRemoteConfigProvider(
            client: mockClient,
            endpoint: "https://example.com/config"
        )
        #expect(provider is NetworkedRemoteConfigProvider)
        #expect(provider.lastFetchDate == nil)
    }

    @Test("InMemoryRemoteConfigProvider conforms to RemoteConfigProvider")
    func inMemoryRemoteConfigConformance() {
        let provider: any RemoteConfigProvider = InMemoryRemoteConfigProvider(
            initialValues: ["key": "value"]
        )
        #expect(provider is InMemoryRemoteConfigProvider)
        #expect(provider.string(forKey: "key") == "value")
    }

    // MARK: - Analytics

    @Test("ConsoleAnalyticsProvider conforms to AnalyticsProvider and track() does not throw")
    func analyticsProviderConformance() {
        let provider: any SyzygyFoundation.AnalyticsProvider = ConsoleAnalyticsProvider()
        #expect(provider is ConsoleAnalyticsProvider)
        // track() is the primary method; call it and verify no crash
        let event = AnalyticsEvent(name: "compliance_check", properties: ["ok": "true"])
        provider.track(event)
        provider.identify(userId: "user123", traits: ["role": "tester"])
        provider.reset()
    }

    // MARK: - Crash Reporting

    @Test("ConsoleCrashReporter conforms to CrashReporter and recordError does not throw")
    func crashReporterConformance() {
        let reporter: any CrashReporter = ConsoleCrashReporter()
        #expect(reporter is ConsoleCrashReporter)
        reporter.setUserContext(userId: "u1", email: "u1@example.com")
        reporter.setMetadata(key: "env", value: "test")
        reporter.recordError(
            URLError(.timedOut),
            metadata: ["context": "compliance_test"]
        )
    }

    // MARK: - WebSocket

    @Test("URLSessionWebSocketProvider conforms to WebSocketProvider and initial state is disconnected")
    func webSocketProviderConformance() async {
        let provider: any WebSocketProvider = URLSessionWebSocketProvider()
        #expect(provider is URLSessionWebSocketProvider)
        let state = await provider.connectionState
        #expect(state == .disconnected)
    }
}

// MARK: - ContractComplianceMockNetworkClient

/// A minimal in-process mock network client for contract compliance tests.
actor ContractComplianceMockNetworkClient: NetworkClientProtocol {
    func execute(_ request: NetworkRequest) async throws -> NetworkResponse {
        NetworkResponse(statusCode: 200, data: Data("{}".utf8), headers: [:])
    }
}
