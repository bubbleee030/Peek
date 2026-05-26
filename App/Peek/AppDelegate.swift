import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let previewController = PreviewController()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Temporary manual trigger to verify the panel before the event tap exists.
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Peek")
        let menu = NSMenu()
        menu.addItem(withTitle: "Preview Home Folder…", action: #selector(previewHome), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Peek", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func previewHome() {
        previewController.show(url: FileManager.default.homeDirectoryForCurrentUser)
    }
}
