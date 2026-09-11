import Testing
import Foundation
@testable import SyzygyServices

@Suite("FileProvider")
struct FileProviderTests {
    @Test("FileManagerFileProvider round-trips data")
    func roundTripsData() throws {
        let provider = FileManagerFileProvider()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).txt")
        let data = Data("hello".utf8)
        try provider.write(data, to: url)
        #expect(provider.exists(at: url))
        let read = try provider.read(from: url)
        #expect(read == data)
        try provider.delete(at: url)
        #expect(!provider.exists(at: url))
    }
}
