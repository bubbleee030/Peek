import Foundation
import PeekCore

@MainActor
final class PreviewViewModel: ObservableObject {
    enum State {
        case loading
        case loaded(PreviewContents)
        case failed(String)
        /// Not a folder or archive: shown with the embedded Quick Look renderer.
        case file(summary: String)
    }

    let url: URL
    @Published private(set) var state: State = .loading

    init(url: URL) { self.url = url }

    var title: String { url.lastPathComponent }

    func load() {
        guard let source = SourceFactory.source(for: url) else {
            state = .file(summary: Self.fileSummary(url))
            return
        }
        Task.detached(priority: .userInitiated) {
            do {
                let contents = try source.read()
                await MainActor.run { self.state = .loaded(contents) }
            } catch let error as ContentSourceError {
                await MainActor.run { self.state = .failed(Self.describe(error)) }
            } catch {
                await MainActor.run { self.state = .failed(error.localizedDescription) }
            }
        }
    }

    /// "1.2 MB • PDF document", from cheap file metadata.
    private static func fileSummary(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .localizedTypeDescriptionKey])
        return [
            values?.fileSize.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) },
            values?.localizedTypeDescription,
        ].compactMap { $0 }.joined(separator: " • ")
    }

    private static func describe(_ error: ContentSourceError) -> String {
        switch error {
        case .cannotRead(let message): return message
        case .unsupported(let message): return message
        }
    }
}
