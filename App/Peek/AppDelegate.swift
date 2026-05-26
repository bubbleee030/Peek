import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let finderContext = FinderContext()
    let previewController = PreviewController()
    private lazy var keyTap = KeyTap(finder: finderContext) { [weak self] url in
        self?.previewController.show(url: url)
    }
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        finderContext.start()
        let granted = keyTap.start()

        // Temporary status item (replaced by MenuBarController in Task 11).
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Peek")
        let menu = NSMenu()
        menu.addItem(withTitle: granted ? "Accessibility: granted" : "Grant Accessibility…",
                     action: #selector(grant), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Peek", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func grant() {
        keyTap.requestAccessibility()
        _ = keyTap.start()
    }
}
