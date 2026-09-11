import Foundation
import SyzygyFoundation

// MARK: - Protocol

/// Defines the contract for file I/O operations.
public protocol FileProvider: Sendable {
    /// Reads data from the file at the given URL.
    func read(from url: URL) throws -> Data
    /// Writes data to the file at the given URL.
    func write(_ data: Data, to url: URL) throws
    /// Deletes the file at the given URL.
    func delete(at url: URL) throws
    /// Returns true if a file exists at the given URL.
    func exists(at url: URL) -> Bool
}

// MARK: - FileManager Implementation

/// A `FileProvider` backed by `FileManager`.
public final class FileManagerFileProvider: FileProvider {
    nonisolated(unsafe) private let fileManager: FileManager

    /// Initialises the provider with a given `FileManager`.
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func write(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }

    public func delete(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    public func exists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
}
