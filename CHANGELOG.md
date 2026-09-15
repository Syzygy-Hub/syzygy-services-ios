# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-09-13

### Added

- Networking retry integration tests using URLProtocol mock (retry count, exponential backoff, server recovery, ceiling enforcement)
- Auth: real token-refresh HTTP flow wired to configurable endpoint; auto-refresh on expired JWT; refresh failure clears tokens and emits AuthState.unauthenticated
- RemoteConfig: cacheTtlSeconds parameter on NetworkedRemoteConfigProvider; fetch() returns cached values within TTL and hits network when stale
- WebSocket: binary payload send tests and mixed text+binary scenario tests
- WebSocket: `binaryMessages() -> AsyncStream<Data>` added to `WebSocketProvider` protocol and `URLSessionWebSocketProvider`; binary frames fan out to dedicated stream without UTF-8 conversion, matching Android's `binaryMessages: Flow<ByteArray>` interface
- PushNotifications: APNs integration documentation and NotificationPayload builder/factory helpers for common notification types (makeAlert, makeBackground, makeBadge); README PushNotifications section added
- Contract compliance test suite verifying every service implements the correct Foundation protocol and primary methods return expected types
- Networking: `BackoffClock` protocol and `TaskBackoffClock` default implementation injectable into `URLSessionNetworkClient`; deterministic retry backoff tests using `MockBackoffClock` (no real wall-clock sleep, matching Android coroutine-test-scheduler pattern)
- DeviceServices: `PlatformDeviceProvider` persists device UUID under `StorageKey` identifier `"syzygy.device.uuid"` in the system Keychain; UUID is generated exactly once and returned consistently on all subsequent calls and across provider re-instantiation
- Persistence: `StorageServiceError` type conforming to `SyzygyError`; `getOrThrow<T>(_:)` method on `UserDefaultsStorageProvider` and `KeychainStorageProvider` — throws `StorageServiceError` with descriptive message (key name, stored type, requested type) when stored data cannot be decoded as `T`
- Networking: optional `logger: (any LoggerProtocol)?` parameter on `URLSessionNetworkClient.init` (defaults to `nil`, zero overhead); logs outgoing request (method, URL, headers minus Authorization, body size), incoming response (status code, duration, body size), and errors
- Networking: `dispose()` method on `URLSessionNetworkClient`; marks client as disposed, calls `session.invalidateAndCancel()`, and causes subsequent `execute(_:)` calls to throw `NetworkServiceError(code: .cancelled)`
- Analytics: `ConsoleAnalyticsProvider.track(_:)` now injects `session_id` (current session UUID) into every event's enriched metadata before logging; `lastTrackedProperties()` test helper exposes last enriched properties
- CrashReporting: `Breadcrumb` value type with `message`, `metadata`, and `timestamp`; `leaveBreadcrumb(message:metadata:)` and `clearBreadcrumbs()` added to `CrashReporter` protocol; `ConsoleCrashReporter` stores the last 20 breadcrumbs in a circular buffer and includes them in `reportCrash` output; `currentBreadcrumbs()` test helper
- WebSocket: `dispose()` method on `URLSessionWebSocketProvider`; closes connection, cancels all tasks, clears message/binary observers, calls `session.invalidateAndCancel()`, and causes subsequent `connect(to:)` and `send` calls to throw `WebSocketError.notConnected`
- Added `canUseBiometric()` and `authenticateWithBiometric(reason:)` stub methods to `AuthProvider` — returns `false`/`.unauthenticated` with doc comments explaining real platform wiring (Face ID / LAContext)
- Added `CONTRACT_TESTS.md` — canonical set of behaviour assertions every Services implementation must satisfy, organised by module

### Fixed

- README version badge corrected to 1.1.0
- README modules table updated with accurate implementation descriptions

### Changed

- NetworkedRemoteConfigProvider initialiser now accepts optional cacheTtlSeconds (default 3600) for cache TTL control
- `URLSessionNetworkClient.init` gains optional `clock: any BackoffClock` parameter (default `TaskBackoffClock`) for injectable retry delays
- `PlatformDeviceProvider` storage key changed from `"com.syzygy.device.id"` to `"syzygy.device.uuid"`

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

[1.1.0]: https://github.com/Syzygy-Hub/syzygy-services-ios/releases/tag/1.1.0
[1.0.0]: https://github.com/Syzygy-Hub/syzygy-services-ios/releases/tag/1.0.0
