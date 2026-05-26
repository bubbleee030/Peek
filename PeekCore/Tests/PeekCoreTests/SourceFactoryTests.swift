import XCTest
@testable import PeekCore

final class SourceFactoryTests: XCTestCase {
    private func tempDir() throws -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("sf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func testFolderReturnsFolderSource() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertTrue(SourceFactory.source(for: dir) is FolderSource)
    }

    func testArchiveExtensionsReturnArchiveSource() {
        for name in ["x.zip", "x.tar", "x.tgz", "x.tar.gz", "x.gz"] {
            let url = URL(fileURLWithPath: "/tmp/\(name)")
            XCTAssertTrue(SourceFactory.source(for: url) is ArchiveSource, "\(name)")
        }
    }

    func testUnsupportedReturnsNil() {
        XCTAssertNil(SourceFactory.source(for: URL(fileURLWithPath: "/tmp/note.txt")))
        XCTAssertNil(SourceFactory.source(for: URL(fileURLWithPath: "/tmp/image.png")))
    }
}
