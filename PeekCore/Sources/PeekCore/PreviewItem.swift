import Foundation

/// One row in a preview listing — a child of a folder, or an entry in an archive.
public struct PreviewItem: Equatable, Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let isDirectory: Bool
    public let sizeBytes: Int64
    public let modified: Date?

    public init(name: String, isDirectory: Bool, sizeBytes: Int64, modified: Date?) {
        self.name = name
        self.isDirectory = isDirectory
        self.sizeBytes = sizeBytes
        self.modified = modified
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
