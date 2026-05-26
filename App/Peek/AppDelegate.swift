import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let finderContext = FinderContext()
    let previewController = PreviewController()
    private lazy var keyTap = KeyTap(
        finder: finderContext,
        isPreviewOpen: { [weak self] in self?.previewController.isOpen ?? false },
        onPreview: { [weak self] url in
            self?.previewController.show(url: url, from: IconLocator.selectedItemRect(matching: url.lastPathComponent))
        },
        onClosePreview: { [weak self] in self?.previewController.close(animated: true) }
    )
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        finderContext.onSelectionChange = { [weak self] in self?.selectionChanged() }
        finderContext.start()
        _ = keyTap.start()
        menuBar = MenuBarController(keyTap: keyTap)
    }

    /// While a preview is open in Finder-navigation mode, follow the selection:
    /// re-preview folders/archives live, and hand non-previewable files to native
    /// Quick Look.
    private func selectionChanged() {
        guard previewController.isOpen, AppSettings.arrowMode == .finderNavigation else { return }
        if let url = finderContext.previewableSelection {
            previewController.update(url: url, from: IconLocator.selectedItemRect(matching: url.lastPathComponent))
        } else {
            previewController.close(animated: false)
            QuickLook.trigger()
        }
    }
}
