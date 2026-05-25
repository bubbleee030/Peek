import Foundation
import XCTest

/// Builds archives in a temp dir from a known tree:
///   a.txt        -> "hello\n"  (6 bytes)
///   sub/b.txt    -> "hi\n"     (3 bytes)
enum ArchiveFixtures {
    struct Built {
        let root: URL
        let zip: URL
        let targz: URL
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

        return Built(root: root, zip: zip, targz: targz)
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
