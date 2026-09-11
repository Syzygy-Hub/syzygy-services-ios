# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-09-12

### Added

- NetworkClient protocol and URLSession-backed HTTP client with async/await
- StorageProvider protocol and UserDefaults-backed key-value persistence
- AuthProvider protocol and JWT token storage and refresh stub
- FileProvider protocol and FileManager-backed file I/O
- PushProvider protocol and APNs token registration stub
- DeviceProvider protocol and UIDevice/ProcessInfo device info implementation
- RemoteConfigProvider protocol and in-memory remote config store
- AnalyticsProvider protocol and console analytics event logging stub
- CrashReporter protocol and console crash logging stub
- WebSocketProvider protocol and URLSessionWebSocketTask WebSocket stub

[1.0.0]: https://github.com/Syzygy-Hub/syzygy-services-ios/releases/tag/1.0.0
