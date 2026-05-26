import AppKit
import PeekCore

/// Polls Finder's current selection via Apple Events, but only while Finder is
/// frontmost, so the spacebar tap can decide instantly from a cached value.
@MainActor
final class FinderContext {
    private var timer: Timer?
    private let script: NSAppleScript?
    private(set) var selectedURLs: [URL] = []

    init() {
        let source = """
        tell application "Finder"
            set out to ""
            repeat with theItem in (selection as alias list)
                set out to out & (POSIX path of theItem) & linefeed
            end repeat
            return out
        end tell
        """
        script = NSAppleScript(source: source)
    }

    func start() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func poll() {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder",
              let script else { return }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        guard errorInfo == nil else { return } // e.g. Automation permission not yet granted
        let text = result.stringValue ?? ""
        selectedURLs = text
            .split(separator: "\n")
            .map { URL(fileURLWithPath: String($0)) }
    }

    /// The single selected item, only if it is a folder or supported archive.
    var previewableSelection: URL? {
        guard selectedURLs.count == 1, let url = selectedURLs.first else { return nil }
        return SourceFactory.source(for: url) != nil ? url : nil
    }
}
