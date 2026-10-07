import AppKit
import PeekCore

/// Reads Finder's selection via Apple Events.
///
/// Space asks Finder directly (`freshPreviewableSelection()`), so it always
/// acts on what is selected *now*. Continuous polling — needed only to follow
/// arrow-key navigation while a preview is open — runs off the main thread so a
/// slow Finder never stalls Peek's UI or its key tap.
@MainActor
final class FinderContext {
    private var timer: Timer?
    private var pollInFlight = false
    private let queue = DispatchQueue(label: "com.bubbleee030.peek.finder-selection", qos: .userInitiated)
    private(set) var selectedURLs: [URL] = []

    /// Called on the main actor whenever the Finder selection changes while following.
    var onSelectionChange: (() -> Void)?

    /// Warms the Apple Event connection off the main thread. This is also where
    /// macOS shows the one-time Automation prompt, so it never blocks the tap.
    func prepare() {
        queue.async { _ = FinderSelection.query(allowPrompt: true) }
    }

    /// Starts polling the selection so an open preview can follow it.
    func startFollowing() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopFollowing() { timer?.invalidate(); timer = nil }

    private func poll() {
        guard !pollInFlight,
              NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else { return }
        pollInFlight = true
        queue.async { [weak self] in
            let urls = FinderSelection.query()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.pollInFlight = false
                    // Ignore results that land after following stopped.
                    guard self.timer != nil, let urls else { return }
                    self.apply(urls)
                }
            }
        }
    }

    private func apply(_ urls: [URL]) {
        guard urls != selectedURLs else { return }
        selectedURLs = urls
        onSelectionChange?()
    }

    /// Queries Finder synchronously (a few ms) and returns the single selected
    /// item if it is a folder or supported archive. Updates the cached selection
    /// without firing `onSelectionChange`.
    func freshPreviewableSelection() -> URL? {
        guard let urls = FinderSelection.query() else { return nil }
        selectedURLs = urls
        return previewableSelection
    }

    /// The single selected item, only if it is a folder or supported archive.
    var previewableSelection: URL? {
        guard selectedURLs.count == 1, let url = selectedURLs.first else { return nil }
        return SourceFactory.source(for: url) != nil ? url : nil
    }
}

/// `get selection as alias list` sent to Finder as a raw Apple Event. Unlike
/// NSAppleScript it is safe off the main thread and takes a timeout.
enum FinderSelection {
    /// The selected items, or `nil` if Finder didn't answer (not running, busy
    /// past the timeout, or Automation permission not granted).
    nonisolated static func query(allowPrompt: Bool = false, timeout: TimeInterval = 0.25) -> [URL]? {
        let finder = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
        let event = NSAppleEventDescriptor.appleEvent(
            withEventClass: code("core"), eventID: code("getd"), // get data
            targetDescriptor: finder,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        // Object specifier for `selection` (a property of the application).
        guard let spec = NSAppleEventDescriptor.record().coerce(toDescriptorType: code("obj ")) else { return nil }
        spec.setDescriptor(NSAppleEventDescriptor(typeCode: code("prop")), forKeyword: code("want"))
        spec.setDescriptor(NSAppleEventDescriptor(enumCode: code("prop")), forKeyword: code("form"))
        spec.setDescriptor(NSAppleEventDescriptor(typeCode: code("sele")), forKeyword: code("seld"))
        spec.setDescriptor(NSAppleEventDescriptor.null(), forKeyword: code("from"))
        event.setParam(spec, forKeyword: code("----"))
        event.setParam(NSAppleEventDescriptor(typeCode: code("alst")), forKeyword: code("rtyp")) // as alias list

        // Without permission, `neverInteract` fails fast instead of prompting.
        let options: NSAppleEventDescriptor.SendOptions = allowPrompt ? [.waitForReply] : [.waitForReply, .neverInteract]
        guard let reply = try? event.sendEvent(options: options, timeout: timeout),
              reply.paramDescriptor(forKeyword: code("errn")) == nil,
              let list = reply.paramDescriptor(forKeyword: code("----")) else { return nil }

        guard list.numberOfItems > 0 else { return [] }
        return (1...list.numberOfItems).compactMap {
            list.atIndex($0)?.coerce(toDescriptorType: code("furl"))?.fileURLValue
        }
    }

    private nonisolated static func code(_ s: String) -> FourCharCode {
        s.utf8.reduce(0) { $0 << 8 | FourCharCode($1) }
    }
}
