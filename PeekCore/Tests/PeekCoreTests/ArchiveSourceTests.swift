import XCTest
@testable import PeekCore

final class ArchiveSourceTests: XCTestCase {
    func testListsZipAsTree() throws {
        let fix = try ArchiveFixtures.build()
        defer { ArchiveFixtures.cleanup(fix) }

        let contents = try ArchiveSource(url: fix.zip).read()
        // Folders first, then files; nested entries live under their folder.
        XCTAssertEqual(contents.items.map(\.name), ["sub", "a.txt"])
        let sub = contents.items[0]
        XCTAssertTrue(sub.isDirectory)
        XCTAssertEqual(sub.children?.map(\.name), ["b.txt"])
        XCTAssertEqual(sub.children?.first?.path, "sub/b.txt")

        let aFile = contents.items[1]
        XCTAssertFalse(aFile.isDirectory)
        XCTAssertNil(aFile.children)
        XCTAssertEqual(aFile.sizeBytes, 6)
        XCTAssertEqual(contents.totalSize, 9) // 6 + 3, directories excluded
    }

    func testListsTarGzAsTree() throws {
        let fix = try ArchiveFixtures.build()
        defer { ArchiveFixtures.cleanup(fix) }

        let contents = try ArchiveSource(url: fix.targz).read()
        XCTAssertEqual(contents.items.map(\.name), ["sub", "a.txt"])
        XCTAssertEqual(contents.items[0].children?.map(\.name), ["b.txt"])
    }

    func testSynthesizesMissingFoldersAndDropsJunk() throws {
        let fix = try ArchiveFixtures.build()
        defer { ArchiveFixtures.cleanup(fix) }

        // No directory entries (-D), plus macOS metadata Archive Utility adds.
        let contents = try ArchiveSource(url: fix.zipNoDirsWithJunk).read()
        XCTAssertEqual(contents.items.map(\.name), ["sub", "a.txt"])
        XCTAssertTrue(contents.items[0].isDirectory)
        XCTAssertEqual(contents.items[0].children?.map(\.name), ["b.txt"])
    }

    func testStripsDotSlashPrefix() throws {
        let fix = try ArchiveFixtures.build()
        defer { ArchiveFixtures.cleanup(fix) }

        let contents = try ArchiveSource(url: fix.dotSlashTar).read()
        XCTAssertEqual(contents.items.map(\.name), ["sub", "a.txt"])
    }

    func testBareGzipListsSingleDecompressedFile() throws {
        let fix = try ArchiveFixtures.build()
        defer { ArchiveFixtures.cleanup(fix) }

        let contents = try ArchiveSource(url: fix.gz).read()
        XCTAssertEqual(contents.items.map(\.name), ["a.txt"])
        XCTAssertEqual(contents.items.first?.isDirectory, false)
        XCTAssertEqual(contents.items.first?.sizeBytes, 6)
        XCTAssertEqual(contents.totalSize, 6)
    }

    func testCorruptArchiveThrowsCannotRead() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("bad-\(UUID().uuidString).zip")
        try Data("not a real archive".utf8).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertThrowsError(try ArchiveSource(url: tmp).read()) { error in
            guard case ContentSourceError.cannotRead = error else {
                return XCTFail("expected cannotRead, got \(error)")
            }
        }
    }
}
