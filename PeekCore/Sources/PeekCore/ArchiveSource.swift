import Foundation
import CLibArchive

public struct ArchiveSource: ContentSource {
    public let url: URL
    public init(url: URL) { self.url = url }

    private static let OK: Int32 = 0          // ARCHIVE_OK
    private static let EOF: Int32 = 1         // ARCHIVE_EOF
    private static let AE_IFMT: UInt16 = 0o170000
    private static let AE_IFDIR: UInt16 = 0o040000

    public func read() throws -> PreviewContents {
        guard let archive = archive_read_new() else {
            throw ContentSourceError.cannotRead("Could not allocate archive reader")
        }
        defer { archive_read_free(archive) }
        archive_read_support_filter_all(archive)
        if isBareGzip {
            // Every-format detection lets weak bidders (e.g. mtree) misclaim a
            // gzipped text file. A gzipped tar still wins the tar bid; anything
            // else falls to `raw`, which yields the single decompressed file.
            archive_read_support_format_tar(archive)
            archive_read_support_format_raw(archive)
        } else {
            archive_read_support_format_all(archive)
        }

        let openResult = url.path.withCString { archive_read_open_filename(archive, $0, 10240) }
        guard openResult == Self.OK else {
            throw ContentSourceError.cannotRead(Self.errorString(archive) ?? "Could not open archive")
        }

        let tree = TreeBuilder()
        while true {
            var entry: OpaquePointer?
            let result = archive_read_next_header(archive, &entry)
            if result == Self.EOF { break }
            guard result == Self.OK, let entry else {
                throw ContentSourceError.cannotRead(Self.errorString(archive) ?? "Corrupt archive entry")
            }
            guard let rawName = archive_entry_pathname(entry) else {
                _ = archive_read_data_skip(archive)
                continue
            }
            var path = String(cString: rawName)
            let filetype = archive_entry_filetype(entry)
            let isDir = (filetype & Self.AE_IFMT) == Self.AE_IFDIR || path.hasSuffix("/")
            var size = Int64(archive_entry_size(entry))
            let mtime = archive_entry_mtime(entry)
            // Raw entries (bare .gz) carry no name or size: tar always sets one.
            if isBareGzip && archive_entry_size_is_set(entry) == 0 {
                path = (url.lastPathComponent as NSString).deletingPathExtension
                size = try Self.countData(archive)
            }
            tree.add(path: path, isDirectory: isDir, size: size,
                     modified: mtime > 0 ? Date(timeIntervalSince1970: TimeInterval(mtime)) : nil)
            _ = archive_read_data_skip(archive)
        }
        return PreviewContents(items: tree.items(), totalSize: tree.totalSize)
    }

    /// A bare `.gz` (not `.tar.gz`) — usually one compressed file, not a tarball.
    private var isBareGzip: Bool {
        let name = url.lastPathComponent.lowercased()
        return name.hasSuffix(".gz") && !name.hasSuffix(".tar.gz")
    }

    /// Decompresses the current entry just to measure it, since gzip has no
    /// reliable size header.
    private static func countData(_ archive: OpaquePointer) throws -> Int64 {
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        var total: Int64 = 0
        while true {
            let n = buffer.withUnsafeMutableBytes { archive_read_data(archive, $0.baseAddress, $0.count) }
            if n == 0 { return total }
            guard n > 0 else {
                throw ContentSourceError.cannotRead(errorString(archive) ?? "Corrupt compressed data")
            }
            total += Int64(n)
        }
    }

    private static func errorString(_ archive: OpaquePointer) -> String? {
        guard let c = archive_error_string(archive) else { return nil }
        let s = String(cString: c)
        return s.isEmpty ? nil : s
    }
}

/// Assembles flat archive paths into a folder tree. Archives often omit
/// directory entries ("sub/b.txt" with no "sub/"), so parents are created on
/// demand; macOS metadata that Finder's Archive Utility also hides is dropped.
private final class TreeBuilder {
    private final class Node {
        var isDirectory = false
        var size: Int64 = 0
        var modified: Date?
        var children: [String: Node] = [:]
    }

    private static let junk: Set<String> = ["__MACOSX", ".DS_Store"]
    private let root = Node()
    private(set) var totalSize: Int64 = 0

    func add(path: String, isDirectory: Bool, size: Int64, modified: Date?) {
        let parts = path.split(separator: "/").map(String.init).filter { $0 != "." && !$0.isEmpty }
        guard !parts.isEmpty, !parts.contains(where: Self.junk.contains) else { return }

        var node = root
        for (i, part) in parts.enumerated() {
            let child = node.children[part] ?? Node()
            node.children[part] = child
            node = child
            if i < parts.count - 1 { child.isDirectory = true }
        }
        if isDirectory {
            node.isDirectory = true
        } else {
            totalSize += size - node.size // a duplicate entry replaces the earlier one
            node.size = size
        }
        node.modified = modified ?? node.modified
    }

    func items() -> [PreviewItem] { Self.items(of: root, prefix: "") }

    private static func items(of node: Node, prefix: String) -> [PreviewItem] {
        node.children.map { name, child in
            let path = prefix + name
            return PreviewItem(
                name: name,
                isDirectory: child.isDirectory,
                sizeBytes: child.isDirectory ? 0 : child.size,
                modified: child.modified,
                path: path,
                children: child.isDirectory ? items(of: child, prefix: path + "/") : nil
            )
        }
        .sorted(by: FolderSource.order)
    }
}
