import Foundation
import SyzygyFoundation
#if canImport(UserNotifications)
import UserNotifications
#endif

// MARK: - NotificationPayload

/// A push notification payload model.
///
/// ## APNs Integration Steps
///
/// ### 1. Enable Push Notifications capability
/// In Xcode → target → Signing & Capabilities, add **Push Notifications**. This adds the
/// `aps-environment` entitlement (development or production) to your app's entitlements file.
///
/// ### 2. Register for remote notifications
/// Call `UIApplication.shared.registerForRemoteNotifications()` after the user grants
/// permission (use ``APNSPushProvider/requestPermission()`` to request it). The system
/// calls `AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`
/// on success — pass the `Data` token straight to ``APNSPushProvider/registerToken(_:)``.
///
/// ### 3. Upload the APNs token to your server
/// After registration, read ``APNSPushProvider/deviceTokenString`` and send it to your
/// backend so it can target this device. Re-upload whenever the token changes (the OS
/// may rotate it across app updates or device restores).
///
/// ### 4. Handle incoming notifications
/// Implement `UNUserNotificationCenterDelegate` in your `AppDelegate` or `SceneDelegate`.
/// Convert the incoming `UNNotificationRequest.content` into a ``NotificationPayload`` and
/// call ``APNSPushProvider/handleNotification(_:)``. Use the factory helpers on
/// ``NotificationPayload`` (``makeAlert(title:body:userInfo:)``,
/// ``makeBackground(action:userInfo:)``, ``makeBadge(count:body:)``) to construct
/// well-typed payloads from raw APNs dictionaries.
///
/// ### 5. Background / data notifications
/// For background refresh payloads (`content-available: 1`), enable the **Background Modes →
/// Remote notifications** capability and implement
/// `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` in your
/// `AppDelegate`. Call `handleNotification` with a ``makeBackground(action:userInfo:)``
/// payload so your registered handler can process the data without showing UI.
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

    // MARK: - Factory helpers

    /// Creates a standard user-visible alert notification.
    ///
    /// Use when the APNs payload contains `aps.alert.title` and `aps.alert.body`.
    /// - Parameters:
    ///   - title: The alert title shown in the notification banner.
    ///   - body: The alert body text.
    ///   - userInfo: Additional key-value data from the APNs payload (excluding `aps`).
    /// - Returns: A ``NotificationPayload`` ready to pass to ``PushProvider/handleNotification(_:)``.
    public static func makeAlert(
        title: String,
        body: String,
        userInfo: [String: String] = [:]
    ) -> NotificationPayload {
        NotificationPayload(title: title, body: body, userInfo: userInfo)
    }

    /// Creates a silent background notification payload.
    ///
    /// Background notifications have `aps.content-available = 1` and no visible alert.
    /// Use this factory to build a payload that signals a background data refresh without
    /// displaying UI to the user.
    /// - Parameters:
    ///   - action: A string identifying the background action (stored under the `"action"` key).
    ///   - userInfo: Additional key-value pairs from the APNs payload.
    /// - Returns: A ``NotificationPayload`` with an empty title/body and `action` in `userInfo`.
    public static func makeBackground(
        action: String,
        userInfo: [String: String] = [:]
    ) -> NotificationPayload {
        var info = userInfo
        info["action"] = action
        return NotificationPayload(title: "", body: "", userInfo: info)
    }

    /// Creates a badge-update notification payload.
    ///
    /// Use when the APNs payload sets `aps.badge` to update the app icon badge count.
    /// - Parameters:
    ///   - count: The new badge count to display on the app icon.
    ///   - body: Optional body text shown in the notification (empty by default for silent badge updates).
    /// - Returns: A ``NotificationPayload`` carrying the badge count as a string in `userInfo`.
    public static func makeBadge(
        count: Int,
        body: String = ""
    ) -> NotificationPayload {
        NotificationPayload(title: "", body: body, userInfo: ["badge": "\(count)"])
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
