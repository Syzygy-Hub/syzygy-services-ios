import Foundation
import SyzygyFoundation
#if canImport(UserNotifications)
import UserNotifications
#endif

// MARK: - NotificationPayload

/// A push notification payload model.
public struct NotificationPayload: Sendable {
    /// The notification title.
    public let title: String
    /// The notification body text.
    public let body: String
    /// Arbitrary string key-value data carried in the notification.
    public let userInfo: [String: String]

    /// Initialises a `NotificationPayload`.
    public init(title: String, body: String, userInfo: [String: String] = [:]) {
        self.title = title
        self.body = body
        self.userInfo = userInfo
    }
}

// MARK: - PushProvider Protocol

/// Defines the contract for push notification registration and handling.
public protocol PushProvider: Sendable {
    /// Requests the user's permission to display push notifications.
    func requestPermission() async -> Bool
    /// Registers the APNs device token. Should be called from `didRegisterForRemoteNotificationsWithDeviceToken`.
    func registerToken(_ token: Data)
    /// The current device token as a hex string, or `nil` if not yet registered.
    var deviceTokenString: String? { get }
    /// Called when an incoming remote notification arrives. Invokes the registered handler.
    func handleNotification(_ payload: NotificationPayload)
    /// Registers a handler to be invoked when a notification arrives.
    func onNotification(_ handler: @Sendable @escaping (NotificationPayload) -> Void)
}

// MARK: - APNSPushProvider

/// A `PushProvider` backed by `UNUserNotificationCenter` that persists the device token.
public final class APNSPushProvider: PushProvider, @unchecked Sendable {

    private let storage: (any SyzygyFoundation.StorageProvider)?
    private static let tokenKey = StorageKey<String>(identifier: "com.syzygy.push.deviceToken")

    private let lock = NSLock()
    nonisolated(unsafe) private var _tokenData: Data?
    nonisolated(unsafe) private var _handler: (@Sendable (NotificationPayload) -> Void)?

    /// Initialises the provider.
    /// - Parameter storage: Optional storage for persisting the device token across launches.
    public init(storage: (any SyzygyFoundation.StorageProvider)? = nil) {
        self.storage = storage
    }

    public func requestPermission() async -> Bool {
#if canImport(UserNotifications)
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
#else
        return false
#endif
    }

    public func registerToken(_ token: Data) {
        lock.withLock {
            _tokenData = token
            let hex = token.map { String(format: "%02x", $0) }.joined()
            storage?.set(hex, for: APNSPushProvider.tokenKey)
        }
    }

    public var deviceTokenString: String? {
        lock.withLock {
            if let data = _tokenData {
                return data.map { String(format: "%02x", $0) }.joined()
            }
            return storage?.get(APNSPushProvider.tokenKey)
        }
    }

    public func handleNotification(_ payload: NotificationPayload) {
        let handler = lock.withLock { _handler }
        handler?(payload)
    }

    public func onNotification(_ handler: @Sendable @escaping (NotificationPayload) -> Void) {
        lock.withLock { _handler = handler }
    }
}
