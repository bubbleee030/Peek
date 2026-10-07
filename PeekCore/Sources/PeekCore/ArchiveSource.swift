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

        var items: [PreviewItem] = []
        var total: Int64 = 0
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
            let name = Self.displayName(path)
            if !name.isEmpty {
                items.append(PreviewItem(
                    name: name,
                    isDirectory: isDir,
                    sizeBytes: size,
                    modified: mtime > 0 ? Date(timeIntervalSince1970: TimeInterval(mtime)) : nil
                ))
                if !isDir { total += size }
            }
            _ = archive_read_data_skip(archive)
        }
        items.sort(by: FolderSource.order)
        return PreviewContents(items: items, totalSize: total)
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

    /// Archive entries are full paths ("sub/b.txt"); show them trimmed of a trailing slash.
    static func displayName(_ path: String) -> String {
        var p = path
        if p.hasSuffix("/") { p.removeLast() }
        return p
    }
}
