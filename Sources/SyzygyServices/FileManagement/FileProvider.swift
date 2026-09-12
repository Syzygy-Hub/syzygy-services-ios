import Foundation
import SyzygyFoundation

// MARK: - FileProvider Protocol

/// Defines the contract for file I/O operations.
public protocol FileProvider: Sendable {
    /// Reads data from the file at the given path.
    func read(from url: URL) throws -> Data
    /// Writes data to the file at the given path, creating intermediate directories as needed.
    func write(_ data: Data, to url: URL) throws
    /// Deletes the file at the given path.
    func delete(at url: URL) throws
    /// Returns `true` if a file (or directory) exists at the given path.
    func exists(at url: URL) -> Bool
    /// Creates a directory at the given path, including intermediate directories.
    func createDirectory(at url: URL) throws
    /// Moves the item at `source` to `destination`.
    func move(from source: URL, to destination: URL) throws
    /// Copies the item at `source` to `destination`.
    func copy(from source: URL, to destination: URL) throws
    /// Returns a URL pointing to the system temporary directory.
    var temporaryDirectory: URL { get }
}

// MARK: - FileManagerFileProvider

/// A `FileProvider` backed by `FileManager`.
public final class FileManagerFileProvider: FileProvider, @unchecked Sendable {

    private let fileManager: FileManager

    /// Initialises the provider with a `FileManager` instance.
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func write(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try data.write(to: url)
    }

    public func delete(at url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    public func exists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    public func createDirectory(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func move(from source: URL, to destination: URL) throws {
        try fileManager.moveItem(at: source, to: destination)
    }

    public func copy(from source: URL, to destination: URL) throws {
        try fileManager.copyItem(at: source, to: destination)
    }

    public var temporaryDirectory: URL {
        fileManager.temporaryDirectory
    }
}
