import XCTest
@testable import PeekCore

final class FolderSourceTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peek-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testListsImmediateChildrenWithSizesAndFoldersFirst() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        try "hello\n".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8) // 6 bytes
        try "hi\n".write(to: dir.appendingPathComponent("z.txt"), atomically: true, encoding: .utf8)    // 3 bytes
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)

        let contents = try FolderSource(url: dir).read()

        XCTAssertEqual(contents.count, 3)
        // folders first, then files alphabetically
        XCTAssertEqual(contents.items.map(\.name), ["sub", "a.txt", "z.txt"])
        XCTAssertTrue(contents.items[0].isDirectory)
        XCTAssertEqual(contents.items[1].sizeBytes, 6)
        XCTAssertEqual(contents.items[2].sizeBytes, 3)
        XCTAssertEqual(contents.totalSize, 9)
    }

    func testSkipsHiddenFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try "x".write(to: dir.appendingPathComponent(".hidden"), atomically: true, encoding: .utf8)
        try "y".write(to: dir.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)

        let contents = try FolderSource(url: dir).read()
        XCTAssertEqual(contents.items.map(\.name), ["visible.txt"])
    }

    func testUnreadableFolderThrowsCannotRead() {
        let missing = URL(fileURLWithPath: "/this/does/not/exist-\(UUID().uuidString)")
        XCTAssertThrowsError(try FolderSource(url: missing).read()) { error in
            guard case ContentSourceError.cannotRead = error else {
                return XCTFail("expected cannotRead, got \(error)")
            }
        }
    }

    func testItemsCarryOnDiskURL() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try "x".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)

        let contents = try FolderSource(url: dir).read()
        let item = try XCTUnwrap(contents.items.first)
        XCTAssertEqual(item.url?.lastPathComponent, "a.txt")
        XCTAssertEqual(item.url?.deletingLastPathComponent().standardizedFileURL,
                       dir.standardizedFileURL)
    }
}
