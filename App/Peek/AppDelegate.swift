import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let finderContext = FinderContext()
    let previewController = PreviewController()
    private lazy var keyTap = KeyTap(
        finder: finderContext,
        isPreviewOpen: { [weak self] in self?.previewController.isOpen ?? false },
        onPreview: { [weak self] url in self?.openPreview(url) },
        onClosePreview: { [weak self] in self?.previewController.close(animated: true) },
        onPassToQuickLook: { [weak self] in self?.followSelection() }
    )
    private var menuBar: MenuBarController?
    /// Native Quick Look appears a beat after its keypress; keep following until then.
    private var followGraceUntil = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        finderContext.onSelectionChange = { [weak self] in self?.selectionChanged() }
        finderContext.prepare()
        finderContext.shouldKeepFollowing = { [weak self] in self?.isPreviewing ?? false }
        _ = keyTap.start()
        menuBar = MenuBarController(keyTap: keyTap)
    }

    /// Opening Peek again while it runs (Finder, Spotlight, Launchpad) brings a
    /// hidden menu-bar icon back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menuBar?.showIcon()
        return false
    }

    private func openPreview(_ url: URL) {
        if QuickLook.isVisible { QuickLook.dismiss() }
        previewController.show(url: url, from: IconLocator.selectedItemRect(matching: url.lastPathComponent))
        followSelection()
    }

    /// Polls the Finder selection while Peek or native Quick Look is showing, so
    /// each can hand off to the other. Only Finder-navigation mode follows;
    /// polling is otherwise idle.
    private func followSelection() {
        guard AppSettings.arrowMode == .finderNavigation else { return }
        followGraceUntil = Date().addingTimeInterval(1)
        finderContext.startFollowing()
    }

    private var isPreviewing: Bool {
        previewController.isOpen || QuickLook.isVisible || Date() < followGraceUntil
    }

    /// Follows the selection in Finder-navigation mode: re-preview folders and
    /// archives live, hand other files to native Quick Look, and take back over
    /// from native Quick Look when the selection lands on a folder or archive.
    private func selectionChanged() {
        guard AppSettings.arrowMode == .finderNavigation else { return }
        let url = finderContext.previewableSelection
        if previewController.isOpen {
            if let url {
                previewController.update(url: url, from: IconLocator.selectedItemRect(matching: url.lastPathComponent))
            } else {
                previewController.close(animated: false)
                QuickLook.trigger()
                followSelection()
            }
        } else if let url, QuickLook.isVisible {
            openPreview(url)
        }
    }
}
