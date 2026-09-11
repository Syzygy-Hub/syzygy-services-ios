[![iOS](https://img.shields.io/badge/iOS-Swift-7F77DD?style=flat)](https://developer.apple.com/ios/) [![Swift](https://img.shields.io/badge/Swift-6.0-1D9E75?logo=swift&logoColor=white&style=flat)](https://swift.org) [![CI](https://img.shields.io/github/actions/workflow/status/Syzygy-Hub/syzygy-services-ios/ci.yml?label=ci&style=flat)](https://github.com/Syzygy-Hub/syzygy-services-ios/actions/workflows/ci.yml) [![Version](https://img.shields.io/badge/version-1.0.0-D85A30?style=flat)](https://github.com/Syzygy-Hub/syzygy-services-ios/releases) [![License](https://img.shields.io/badge/License-MIT-green?style=flat)](LICENSE)

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
| **Auth** | AuthProvider protocol + JWT token storage and refresh stub |
| **FileManagement** | FileProvider protocol + FileManager-backed file I/O |
| **PushNotifications** | PushProvider protocol + APNs token registration stub |
| **DeviceServices** | DeviceProvider protocol + UIDevice/ProcessInfo implementation |
| **RemoteConfig** | RemoteConfigProvider protocol + in-memory config store |
| **Analytics** | AnalyticsProvider protocol + console event logging stub |
| **CrashReporting** | CrashReporter protocol + console crash logging stub |
| **WebSocket** | WebSocketProvider protocol + URLSessionWebSocketTask implementation stub |

---

## Installation

Add the dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Syzygy-Hub/syzygy-services-ios", from: "1.0.0")
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

## License

MIT — see [LICENSE](LICENSE) for details.
