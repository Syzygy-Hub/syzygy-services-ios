import Foundation
import SyzygyFoundation

// MARK: - Protocol

/// Defines the contract for push notification registration and handling.
public protocol PushProvider: Sendable {
    /// Registers the device with the given APNs device token.
    func registerToken(_ token: Data)
    /// Returns the current device token as a hex string, or nil if not registered.
    var deviceTokenString: String? { get }
}

// MARK: - APNs Stub Implementation

/// An `PushProvider` that stores an APNs device token in memory.
public final class APNSPushProvider: PushProvider {
    nonisolated(unsafe) private var _tokenData: Data?

    /// Initialises the provider.
    public init() {}

    public func registerToken(_ token: Data) {
        _tokenData = token
    }

    public var deviceTokenString: String? {
        _tokenData?.map { String(format: "%02x", $0) }.joined()
    }
}
