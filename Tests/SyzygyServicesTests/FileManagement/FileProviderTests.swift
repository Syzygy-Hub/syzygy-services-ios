import Testing
import Foundation
@testable import SyzygyServices

@Suite("FileProvider")
struct FileProviderTests {

    private func tempURL(_ name: String? = nil) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(name ?? "syzygy-test-\(UUID().uuidString)")
    }

    @Test("write/read round-trips data")
    func writeReadRoundTrip() throws {
        let provider = FileManagerFileProvider()
        let url = tempURL("data.bin")
        defer { try? provider.delete(at: url) }
        let data = Data("hello syzygy".utf8)
        try provider.write(data, to: url)
        let read = try provider.read(from: url)
        #expect(read == data)
    }

    @Test("exists returns true after write, false after delete")
    func existsAfterWriteDelete() throws {
        let provider = FileManagerFileProvider()
        let url = tempURL("exists.txt")
        try provider.write(Data("x".utf8), to: url)
        #expect(provider.exists(at: url))
        try provider.delete(at: url)
        #expect(!provider.exists(at: url))
    }

    @Test("move renames file")
    func moveRenamesFile() throws {
        let provider = FileManagerFileProvider()
        let src = tempURL("src.txt")
        let dst = tempURL("dst.txt")
        defer { try? provider.delete(at: dst) }
        try provider.write(Data("move me".utf8), to: src)
        try provider.move(from: src, to: dst)
        #expect(!provider.exists(at: src))
        #expect(provider.exists(at: dst))
    }

    @Test("copy duplicates file content")
    func copyDuplicatesFile() throws {
        let provider = FileManagerFileProvider()
        let src = tempURL("orig.txt")
        let dst = tempURL("copy.txt")
        defer {
            try? provider.delete(at: src)
            try? provider.delete(at: dst)
        }
        let data = Data("copy me".utf8)
        try provider.write(data, to: src)
        try provider.copy(from: src, to: dst)
        #expect(provider.exists(at: src))
        #expect(try provider.read(from: dst) == data)
    }

    @Test("temporaryDirectory is non-empty and exists")
    func temporaryDirectory() {
        let provider = FileManagerFileProvider()
        #expect(provider.exists(at: provider.temporaryDirectory))
    }

    @Test("createDirectory creates nested path")
    func createDirectory() throws {
        let provider = FileManagerFileProvider()
        let dir = tempURL().appendingPathComponent("nested/deep")
        defer { try? FileManager.default.removeItem(at: tempURL()) }
        try provider.createDirectory(at: dir)
        #expect(provider.exists(at: dir))
    }
}
