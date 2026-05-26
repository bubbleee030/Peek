import AppKit
import UniformTypeIdentifiers
import PeekCore

/// Resolves the real Finder icon for a preview row.
enum FileIcon {
    static func image(for item: PreviewItem) -> NSImage {
        // Folder children have a real path — use the exact icon Finder shows
        // (custom folder icons, app bundles, document thumbnails, etc.).
        if let url = item.url {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        // Archive entries have no on-disk path; derive an icon from the type.
        if item.isDirectory {
            return NSWorkspace.shared.icon(for: .folder)
        }
        let ext = (item.name as NSString).pathExtension
        if !ext.isEmpty, let type = UTType(filenameExtension: ext) {
            return NSWorkspace.shared.icon(for: type)
        }
        return NSWorkspace.shared.icon(for: .data)
    }
}
