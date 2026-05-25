import Foundation

public struct FolderSource: ContentSource {
    public let url: URL
    public init(url: URL) { self.url = url }

    private static let keys: [URLResourceKey] = [
        .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .nameKey,
    ]

    public func read() throws -> PreviewContents {
        let fm = FileManager.default
        let entries: [URL]
        do {
            entries = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Self.keys,
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw ContentSourceError.cannotRead(error.localizedDescription)
        }

        var items: [PreviewItem] = []
        var total: Int64 = 0
        for entry in entries {
            let values = try? entry.resourceValues(forKeys: Set(Self.keys))
            let isDir = values?.isDirectory ?? false
            let size = Int64(values?.fileSize ?? 0)
            let name = values?.name ?? entry.lastPathComponent
            items.append(PreviewItem(
                name: name,
                isDirectory: isDir,
                sizeBytes: size,
                modified: values?.contentModificationDate
            ))
            total += size
        }
        items.sort(by: Self.order)
        return PreviewContents(items: items, totalSize: total)
    }

    /// Folders first, then localized natural name order. Shared with ArchiveSource.
    public static func order(_ a: PreviewItem, _ b: PreviewItem) -> Bool {
        if a.isDirectory != b.isDirectory { return a.isDirectory }
        return a.name.localizedStandardCompare(b.name) == .orderedAscending
    }
}
