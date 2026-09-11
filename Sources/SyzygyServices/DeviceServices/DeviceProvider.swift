import Foundation
import SyzygyFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Protocol

/// Defines the contract for accessing device information.
public protocol DeviceProvider: Sendable {
    /// The device model name (e.g. "iPhone 15 Pro").
    var model: String { get }
    /// The operating system name (e.g. "iOS").
    var systemName: String { get }
    /// The operating system version string (e.g. "17.0").
    var systemVersion: String { get }
    /// A unique identifier for the device installation.
    var identifierForVendor: String? { get }
}

// MARK: - Platform Implementation

/// A `DeviceProvider` backed by `UIDevice` (iOS) or `ProcessInfo` (macOS).
public final class PlatformDeviceProvider: DeviceProvider {
    /// Initialises the provider.
    public init() {}

#if canImport(UIKit)
    public var model: String { UIDevice.current.model }
    public var systemName: String { UIDevice.current.systemName }
    public var systemVersion: String { UIDevice.current.systemVersion }
    public var identifierForVendor: String? { UIDevice.current.identifierForVendor?.uuidString }
#else
    public var model: String { "Mac" }
    public var systemName: String { "macOS" }
    public var systemVersion: String { ProcessInfo.processInfo.operatingSystemVersionString }
    public var identifierForVendor: String? { nil }
#endif
}
