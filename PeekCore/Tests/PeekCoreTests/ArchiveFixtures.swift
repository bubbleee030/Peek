import Foundation
import XCTest

/// Builds archives in a temp dir from a known tree:
///   a.txt        -> "hello\n"  (6 bytes)
///   sub/b.txt    -> "hi\n"     (3 bytes)
/// plus a bare gzip of a.txt (not a tarball), a zip with no directory
/// entries but macOS junk (__MACOSX/, .DS_Store), and a tar of "./".
enum ArchiveFixtures {
    struct Built {
        let root: URL
        let zip: URL
        let targz: URL
        let gz: URL
        let zipNoDirsWithJunk: URL
        let dotSlashTar: URL
    }

    static func build() throws -> Built {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("peekfix-\(UUID().uuidString)")
        let payload = root.appendingPathComponent("payload")
        try fm.createDirectory(at: payload.appendingPathComponent("sub"), withIntermediateDirectories: true)
        try "hello\n".write(to: payload.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "hi\n".write(to: payload.appendingPathComponent("sub/b.txt"), atomically: true, encoding: .utf8)

        let zip = root.appendingPathComponent("fixture.zip")
        try run("/usr/bin/zip", ["-r", "-q", zip.path, "a.txt", "sub"], cwd: payload)

        let targz = root.appendingPathComponent("fixture.tar.gz")
        try run("/usr/bin/tar", ["-czf", targz.path, "-C", payload.path, "a.txt", "sub"], cwd: nil)

        let gz = root.appendingPathComponent("a.txt.gz")
        try run("/usr/bin/gzip", ["-k", payload.appendingPathComponent("a.txt").path], cwd: nil)
        try fm.moveItem(at: payload.appendingPathComponent("a.txt.gz"), to: gz)

        let junkDir = root.appendingPathComponent("junk")
        try fm.copyItem(at: payload, to: junkDir)
        try "x".write(to: junkDir.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)
        try fm.createDirectory(at: junkDir.appendingPathComponent("__MACOSX/sub"), withIntermediateDirectories: true)
        try "x".write(to: junkDir.appendingPathComponent("__MACOSX/sub/._b.txt"), atomically: true, encoding: .utf8)
        let zipNoDirsWithJunk = root.appendingPathComponent("nodirs.zip")
        try run("/usr/bin/zip", ["-r", "-q", "-D", zipNoDirsWithJunk.path, "."], cwd: junkDir)

        let dotSlashTar = root.appendingPathComponent("dotslash.tar")
        try run("/usr/bin/tar", ["-cf", dotSlashTar.path, "-C", payload.path, "."], cwd: nil)

        return Built(root: root, zip: zip, targz: targz, gz: gz,
                     zipNoDirsWithJunk: zipNoDirsWithJunk, dotSlashTar: dotSlashTar)
    }

    static func cleanup(_ built: Built) {
        try? FileManager.default.removeItem(at: built.root)
    }

    private static func run(_ launchPath: String, _ args: [String], cwd: URL?) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        if let cwd { p.currentDirectoryURL = cwd }
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            throw NSError(domain: "ArchiveFixtures", code: Int(p.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "\(launchPath) failed"])
        }
    }
}
