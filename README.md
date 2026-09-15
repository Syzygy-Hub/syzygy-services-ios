[![iOS](https://img.shields.io/badge/iOS-Swift-7F77DD?style=flat)](https://developer.apple.com/ios/) [![Swift](https://img.shields.io/badge/Swift-6.0-1D9E75?logo=swift&logoColor=white&style=flat)](https://swift.org) [![CI](https://img.shields.io/github/actions/workflow/status/Syzygy-Hub/syzygy-services-ios/ci.yml?label=ci&style=flat)](https://github.com/Syzygy-Hub/syzygy-services-ios/actions/workflows/ci.yml) [![Version](https://img.shields.io/badge/version-1.1.0-D85A30?style=flat)](https://github.com/Syzygy-Hub/syzygy-services-ios/releases) [![License](https://img.shields.io/badge/License-MIT-green?style=flat)](LICENSE)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/Syzygy-Hub/.github/main/brand/assets/banners/syzygy-banner-dark-1200.png">
  <img src="https://raw.githubusercontent.com/Syzygy-Hub/.github/main/brand/assets/banners/syzygy-banner-light-1200.png" alt="Syzygy" width="600">
</picture>

# syzygy-services-ios

Concrete I/O service implementations for the Syzygy iOS ecosystem — networking, persistence, auth, file management, push notifications, device services, remote config, analytics, crash reporting, and WebSocket.

---

## Modules

| Module | Description |
|---|---|
| **Networking** | NetworkClient protocol + URLSession-backed HTTP client with async/await |
| **Persistence** | StorageProvider protocol + UserDefaults-backed key-value store |
| **Auth** | AuthProvider protocol + JWT token storage with real HTTP refresh flow and auto-refresh on expiry |
| **FileManagement** | FileProvider protocol + FileManager-backed file I/O |
| **PushNotifications** | PushProvider protocol + APNs token registration and NotificationPayload factory helpers |
| **DeviceServices** | DeviceProvider protocol + UIDevice/ProcessInfo implementation |
| **RemoteConfig** | RemoteConfigProvider protocol + in-memory and networked remote config store with cache TTL |
| **Analytics** | AnalyticsProvider protocol + console event logging with session-ID enrichment |
| **CrashReporting** | CrashReporter protocol + console crash logging with breadcrumb circular buffer |
| **WebSocket** | WebSocketProvider protocol + URLSessionWebSocketTask implementation with binary message stream |

---

## Installation

Add the dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Syzygy-Hub/syzygy-services-ios", from: "1.1.0")
]
```

Then add `SyzygyServices` to your target's dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "SyzygyServices", package: "syzygy-services-ios")
    ]
)
```

---

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- Xcode 16.0+

---

## Dependencies

| Package | Version |
|---|---|
| syzygy-foundation-ios | 1.1.0 |

---

## Ecosystem

This repo is part of the **Syzygy** cross-platform mobile ecosystem. See the [ecosystem architecture](https://github.com/Syzygy-Hub/.github/blob/main/engineering/architecture/syzygy-ecosystem.md) for how the layers fit together.

---

## Push Notifications

`SyzygyServices` ships a ready-to-use APNs integration via `APNSPushProvider`.

### Quick-start

```swift
import SyzygyServices

let push = APNSPushProvider()

// 1. Request permission
let granted = await push.requestPermission()

// 2. Register the device token (call from AppDelegate)
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    push.registerToken(deviceToken)
    // Upload push.deviceTokenString to your server here
}

// 3. Register a notification handler
push.onNotification { payload in
    print("Received: \(payload.title) — \(payload.body)")
}

// 4. Deliver incoming notifications (call from UNUserNotificationCenterDelegate)
push.handleNotification(NotificationPayload.makeAlert(title: "Hello", body: "World"))
```

### Factory helpers

| Helper | Use case |
|---|---|
| `NotificationPayload.makeAlert(title:body:userInfo:)` | Standard user-visible alert (has `aps.alert`) |
| `NotificationPayload.makeBackground(action:userInfo:)` | Silent background refresh (`aps.content-available = 1`) |
| `NotificationPayload.makeBadge(count:body:)` | Badge-count update (`aps.badge`) |

### APNs integration steps

1. **Enable capability** — Xcode → target → Signing & Capabilities → *Push Notifications*
2. **Register** — call `UIApplication.shared.registerForRemoteNotifications()` after permission is granted
3. **Upload token** — send `APNSPushProvider.deviceTokenString` to your backend
4. **Handle alerts** — implement `UNUserNotificationCenterDelegate` and pass payloads to `handleNotification(_:)`
5. **Background mode** — enable *Background Modes → Remote notifications* for `content-available` payloads

Full inline documentation is in `Sources/SyzygyServices/PushNotifications/PushProvider.swift`.

---

## License

MIT — see [LICENSE](LICENSE) for details.
