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
    /// True while one preview is animating away before the other animates in.
    private var isHandingOff = false

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
        isHandingOff || previewController.isOpen || QuickLook.isVisible || Date() < followGraceUntil
    }

    /// Follows the selection in Finder-navigation mode: re-preview folders and
    /// archives live, hand other files to native Quick Look, and take back over
    /// from native Quick Look when the selection lands on a folder or archive.
    ///
    /// Handoffs run in sequence — the outgoing preview shrinks into the selected
    /// icon, then the incoming one grows out of it — with Peek's timing matched
    /// to native Quick Look's, so the two never animate on top of each other.
    private func selectionChanged() {
        guard AppSettings.arrowMode == .finderNavigation, !isHandingOff else { return }
        let url = finderContext.previewableSelection
        if previewController.isOpen {
            if let url {
                previewController.update(url: url, from: IconLocator.selectedItemRect(matching: url.lastPathComponent))
            } else {
                handOffToQuickLook()
            }
        } else if url != nil, QuickLook.isVisible {
            handOffToPeek()
        }
    }

    /// Peek → native: shrink Peek into the newly selected icon while native
    /// Quick Look starts up. Its panel takes ~0.2s to appear after the
    /// keypress — about as long as Peek's close — so it grows out of the icon
    /// just as Peek finishes shrinking into it.
    private func handOffToQuickLook() {
        isHandingOff = true
        let iconRect = finderContext.singleSelection.flatMap { IconLocator.selectedItemRect(matching: $0.lastPathComponent) }
        QuickLook.trigger()
        previewController.close(animated: true, into: iconRect) { [weak self] in
            guard let self else { return }
            self.isHandingOff = false
            self.followSelection()
            // Arrowed back onto a folder meanwhile: once native Quick Look is
            // up, hand straight back.
            if self.finderContext.previewableSelection != nil {
                self.wait(until: { QuickLook.isVisible }, timeout: 0.6) { self.handOffToPeek() }
            }
        }
    }

    /// Native → Peek: close native Quick Look (it shrinks into the selected
    /// icon over ~0.2s), then grow Peek out of the same icon. The icon and the
    /// panel are prepared up front, while Quick Look is still animating, so
    /// Peek appears the moment Quick Look is done.
    private func handOffToPeek() {
        isHandingOff = true
        QuickLook.dismiss()
        let closeDeadline = AppSettings.Animation.closeDuration
        let started = Date()
        let target = finderContext.previewableSelection
        let iconRect = target.flatMap { IconLocator.selectedItemRect(matching: $0.lastPathComponent) }
        let prepared = target.map { previewController.prepare(url: $0) }
        let remaining = max(0, closeDeadline - Date().timeIntervalSince(started))
        wait(until: { !QuickLook.isVisible }, timeout: remaining) { [weak self] in
            guard let self else { return }
            self.isHandingOff = false
            // Show whatever fits the selection *now* — the user may have kept
            // arrowing while Quick Look closed.
            if let url = self.finderContext.previewableSelection {
                if let prepared, prepared.url == url {
                    self.previewController.show(prepared, from: iconRect)
                } else {
                    self.previewController.show(url: url, from: IconLocator.selectedItemRect(matching: url.lastPathComponent))
                }
                self.followSelection()
            } else if !self.finderContext.selectedURLs.isEmpty {
                QuickLook.trigger()
                self.followSelection()
            }
        }
    }

    /// Polls `condition` every frame until it holds or `timeout` passes.
    private func wait(until condition: @escaping @MainActor () -> Bool, timeout: TimeInterval,
                      then done: @escaping @MainActor () -> Void) {
        let deadline = Date().addingTimeInterval(timeout)
        func check() {
            guard !condition(), Date() < deadline else { return done() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { MainActor.assumeIsolated { check() } }
        }
        check()
    }
}
