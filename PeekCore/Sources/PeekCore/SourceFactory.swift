import Foundation

public enum SourceFactory {
    /// Single-extension archive types. `.tar.gz` is handled by suffix below.
    public static let archiveExtensions: Set<String> = ["zip", "zipx", "tar", "gz", "tgz"]

    public static func source(for url: URL) -> ContentSource? {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            return FolderSource(url: url)
        }
        let lastComponent = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        if lastComponent.hasSuffix(".tar.gz") || archiveExtensions.contains(ext) {
            return ArchiveSource(url: url)
        }
        return nil
    }
}
