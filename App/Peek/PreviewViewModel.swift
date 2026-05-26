import Foundation
import PeekCore

@MainActor
final class PreviewViewModel: ObservableObject {
    enum State {
        case loading
        case loaded(PreviewContents)
        case failed(String)
    }

    let url: URL
    @Published private(set) var state: State = .loading

    init(url: URL) { self.url = url }

    var title: String { url.lastPathComponent }

    func load() {
        guard let source = SourceFactory.source(for: url) else {
            state = .failed("Peek can't preview this item.")
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

    private static func describe(_ error: ContentSourceError) -> String {
        switch error {
        case .cannotRead(let message): return message
        case .unsupported(let message): return message
        }
    }
}
