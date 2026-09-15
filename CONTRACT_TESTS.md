# Syzygy Services — Contract Tests Reference

This document defines the canonical set of behaviour assertions every Syzygy Services
implementation must satisfy. It serves as the source of truth for cross-platform contract
compliance.

## How to use this document

Each section lists the minimum test cases required per module. Tests marked ✅ are already
implemented in this repo's test suite; tests marked 🔲 are not yet implemented.

---

## Networking

| Test | Status |
|------|--------|
| Successful GET request returns 200 body | ✅ |
| Retries on 5xx responses up to maxRetries | ✅ |
| Does NOT retry on 4xx responses | ✅ |
| Retry delays use injected BackoffClock (not real sleep) | ✅ |
| Recovers on Nth attempt after N-1 failures | ✅ |
| Logger receives request method, URL, headers (Authorization stripped) | ✅ |
| Logger receives response status, body size, elapsed time | ✅ |
| dispose() cancels in-flight requests | ✅ |
| dispose() is idempotent | ✅ |

## Persistence

| Test | Status |
|------|--------|
| Stores and retrieves a value by key | ✅ |
| Returns nil for missing key | ✅ |
| Type mismatch throws descriptive error with key name, stored type, requested type | ✅ |
| Secure storage stores and retrieves | ✅ |

## Auth

| Test | Status |
|------|--------|
| Initial state is unauthenticated | ✅ |
| setToken() transitions to authenticated | ✅ |
| clearTokens() transitions to unauthenticated | ✅ |
| refresh() POSTs to refreshEndpoint, updates stored tokens | ✅ |
| refresh() on expired JWT auto-refreshes before request | ✅ |
| refresh() failure transitions to unauthenticated | ✅ |
| canUseBiometric() returns false on stub | ✅ |
| authenticateWithBiometric() returns unauthenticated on stub | ✅ |

## FileManagement

| Test | Status |
|------|--------|
| Writes and reads a file | ✅ |
| Returns nil for missing file | ✅ |
| Deletes a file | ✅ |

## PushNotifications

| Test | Status |
|------|--------|
| Registers for notifications without throwing | ✅ |
| NotificationPayload factory creates alert payload | ✅ |
| NotificationPayload factory creates silent payload | ✅ |

## DeviceServices

| Test | Status |
|------|--------|
| deviceId() returns consistent UUID across calls | ✅ |
| deviceId() is stored under key "syzygy.device.uuid" | ✅ |

## RemoteConfig

| Test | Status |
|------|--------|
| fetchConfig() returns values | ✅ |
| Cache hit: second fetch within TTL does not call network | ✅ |
| Cache miss: fetch after TTL calls network | ✅ |

## Analytics

| Test | Status |
|------|--------|
| track() records event | ✅ |
| Session ID injected into every event | ✅ |
| reset() regenerates session ID | ✅ |

## CrashReporting

| Test | Status |
|------|--------|
| recordCrash() records crash | ✅ |
| leaveBreadcrumb() records breadcrumb | ✅ |
| Breadcrumb buffer limited to 20 | ✅ |
| clearBreadcrumbs() empties buffer | ✅ |
| Breadcrumbs included in crash record | ✅ |

## WebSocket

| Test | Status |
|------|--------|
| Connects successfully | ✅ |
| Sends and receives text messages | ✅ |
| binaryMessages stream accessible via protocol type | ✅ |
| sendBytes() emits to binary stream | ✅ |
| dispose() closes connection | ✅ |
| dispose() is idempotent | ✅ |
