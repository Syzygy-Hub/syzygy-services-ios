import Foundation
import SyzygyFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - DeviceProvider Protocol

/// Defines the contract for accessing device information.
public protocol DeviceProvider: Sendable {
    /// A persistent unique identifier for this device/installation (stored in Keychain).
    var deviceId: String { get }
    /// The platform name — always `"ios"` on iOS targets.
    var platform: String { get }
    /// The OS version string (e.g. `"17.2"`).
    var osVersion: String { get }
    /// The marketing version of the app (e.g. `"1.0.0"`), or `"unknown"` if unavailable.
    var appVersion: String { get }
    /// `true` when running inside the Xcode Simulator.
    var isSimulator: Bool { get }
}

// MARK: - PlatformDeviceProvider

/// A `DeviceProvider` backed by platform APIs.
public final class PlatformDeviceProvider: DeviceProvider, @unchecked Sendable {

    private let storage: KeychainStorageProvider
    private static let deviceIdKey = StorageKey<String>(identifier: "syzygy.device.uuid")

    private let lock = NSLock()
    nonisolated(unsafe) private var _cachedDeviceId: String?

    /// Initialises the provider.
    /// - Parameter storage: The Keychain storage used to persist the device ID.
    public init(storage: KeychainStorageProvider = KeychainStorageProvider()) {
        self.storage = storage
    }

    public var deviceId: String {
        lock.withLock {
            if let cached = _cachedDeviceId { return cached }
            if let stored = storage.get(PlatformDeviceProvider.deviceIdKey) {
                _cachedDeviceId = stored
                return stored
            }
            let newId = UUID().uuidString
            storage.set(newId, for: PlatformDeviceProvider.deviceIdKey)
            _cachedDeviceId = newId
            return newId
        }
    }

    public var platform: String { "ios" }

    public var osVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    public var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    public var isSimulator: Bool {
#if targetEnvironment(simulator)
        return true
#else
        return false
#endif
    }

    // MARK: - Legacy compat properties

    /// The device model name.
    public var model: String {
#if canImport(UIKit)
        return UIDevice.current.model
#else
        return "Mac"
#endif
    }

    /// The operating system name.
    public var systemName: String {
#if canImport(UIKit)
        return UIDevice.current.systemName
#else
        return "macOS"
#endif
    }

    /// Alias for `osVersion` for backward compatibility.
    public var systemVersion: String { osVersion }

    /// The vendor identifier if available.
    public var identifierForVendor: String? {
#if canImport(UIKit)
        return UIDevice.current.identifierForVendor?.uuidString
#else
        return nil
#endif
    }
}
