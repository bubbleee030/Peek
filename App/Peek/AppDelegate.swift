import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let finderContext = FinderContext()
    let previewController = PreviewController()
    private lazy var keyTap = KeyTap(finder: finderContext) { [weak self] url in
        self?.previewController.show(url: url)
    }
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        finderContext.start()
        _ = keyTap.start()
        menuBar = MenuBarController(keyTap: keyTap)
    }
}
