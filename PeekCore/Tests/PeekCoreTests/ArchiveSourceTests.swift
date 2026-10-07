import XCTest
@testable import PeekCore

final class ArchiveSourceTests: XCTestCase {
    func testListsZipEntriesWithSizes() throws {
        let fix = try ArchiveFixtures.build()
        defer { ArchiveFixtures.cleanup(fix) }

        let contents = try ArchiveSource(url: fix.zip).read()
        let names = Set(contents.items.map(\.name))
        XCTAssertTrue(names.contains("a.txt"), "names were \(names)")
        XCTAssertTrue(names.contains("sub/b.txt"), "names were \(names)")

        let aFile = contents.items.first { $0.name == "a.txt" }
        XCTAssertEqual(aFile?.isDirectory, false)
        XCTAssertEqual(aFile?.sizeBytes, 6)
        XCTAssertEqual(contents.totalSize, 9) // 6 + 3, directories excluded
    }

    func testListsTarGzEntries() throws {
        let fix = try ArchiveFixtures.build()
        defer { ArchiveFixtures.cleanup(fix) }

        let contents = try ArchiveSource(url: fix.targz).read()
        let names = Set(contents.items.map(\.name))
        XCTAssertTrue(names.contains("a.txt"), "names were \(names)")
        XCTAssertTrue(names.contains("sub/b.txt"), "names were \(names)")
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
