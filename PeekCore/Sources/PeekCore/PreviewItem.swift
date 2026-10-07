import Foundation

/// One row in a preview listing — a child of a folder, or an entry in an archive.
public struct PreviewItem: Equatable, Identifiable, Sendable {
    public var id: String { path }
    public let name: String
    /// Unique within a listing: the entry's path inside an archive ("sub/b.txt"),
    /// or just the name for a folder's direct children.
    public let path: String
    public let isDirectory: Bool
    public let sizeBytes: Int64
    public let modified: Date?
    /// Full on-disk location, for items that exist as real files (folder children).
    /// `nil` for archive entries, which have no path on disk to fetch an icon from.
    public let url: URL?
    /// Nested entries of an archive folder, sorted. `nil` for files and for
    /// folder children (which are not expanded).
    public let children: [PreviewItem]?

    public init(name: String, isDirectory: Bool, sizeBytes: Int64, modified: Date?,
                url: URL? = nil, path: String? = nil, children: [PreviewItem]? = nil) {
        self.name = name
        self.path = path ?? name
        self.isDirectory = isDirectory
        self.sizeBytes = sizeBytes
        self.modified = modified
        self.url = url
        self.children = children
    }
}

/// The full result of reading a folder or archive.
public struct PreviewContents: Equatable, Sendable {
    public let items: [PreviewItem]
    public let totalSize: Int64
    public var count: Int { items.count }

    public init(items: [PreviewItem], totalSize: Int64) {
        self.items = items
        self.totalSize = totalSize
    }
}
