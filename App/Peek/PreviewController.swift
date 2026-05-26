import AppKit
import SwiftUI

/// A panel that only takes key focus when we explicitly allow it — so in
/// Finder-navigation mode it floats above Finder without stealing focus.
final class PreviewPanel: NSPanel {
    var allowKey = false
    override var canBecomeKey: Bool { allowKey }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PreviewController {
    private var panel: PreviewPanel?
    private var hosting: NSHostingView<PreviewView>?
    private var keyMonitor: Any?
    private var mode: AppSettings.ArrowMode = .finderNavigation
    private var previousApp: NSRunningApplication?
    private var originRect: NSRect?

    private static let panelSize = NSSize(width: 560, height: 460)

    var isOpen: Bool { panel != nil }

    /// Opens (replacing any existing) a preview for `url`, zooming out from
    /// `iconRect` (the selected item's on-screen rect) when available.
    func show(url: URL, from iconRect: NSRect?) {
        close(animated: false)
        mode = AppSettings.arrowMode

        let model = PreviewViewModel(url: url)
        let hosting = NSHostingView(rootView: PreviewView(model: model))
        self.hosting = hosting

        let panel = PreviewPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.contentView = hosting
        self.panel = panel

        let target = centeredFrame(size: Self.panelSize)
        originRect = iconRect

        switch mode {
        case .finderNavigation:
            // Never steal focus — Finder stays active so arrow keys keep driving
            // its selection, and focus is already "returned" when we close.
            panel.allowKey = false
            present(panel, target: target, from: iconRect, makeKey: false)
        case .previewScroll:
            // Take focus so arrow keys scroll the list; remember Finder to restore.
            previousApp = NSWorkspace.shared.frontmostApplication
            panel.allowKey = true
            NSApp.activate(ignoringOtherApps: true)
            present(panel, target: target, from: iconRect, makeKey: true)
            installLocalKeyMonitor()
            NotificationCenter.default.addObserver(
                self, selector: #selector(resigned(_:)),
                name: NSWindow.didResignKeyNotification, object: panel
            )
        }
        model.load()
    }

    /// Swaps the previewed item without re-animating — used while the user
    /// arrows through Finder with the panel already open. Refreshes the origin
    /// rect so a later close zooms back into the now-selected icon.
    func update(url: URL, from iconRect: NSRect?) {
        guard panel != nil, let hosting else { return }
        if let iconRect { originRect = iconRect }
        let model = PreviewViewModel(url: url)
        hosting.rootView = PreviewView(model: model)
        model.load()
    }

    func close(animated: Bool) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil

        guard let panel else { return }
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: panel)
        let appToRestore = (mode == .previewScroll) ? previousApp : nil
        self.panel = nil
        self.hosting = nil
        self.previousApp = nil

        let dismiss = {
            panel.orderOut(nil)
            appToRestore?.activate()
        }

        if animated && AppSettings.zoomEffect {
            let endRect = originRect ?? Self.shrunk(panel.frame)
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = AppSettings.animationDuration * 0.8
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(endRect, display: true)
                panel.animator().alphaValue = 0
            }, completionHandler: dismiss)
        } else {
            dismiss()
        }
        originRect = nil
    }

    // MARK: - Presentation

    private func present(_ panel: PreviewPanel, target: NSRect, from iconRect: NSRect?, makeKey: Bool) {
        let order = { makeKey ? panel.makeKeyAndOrderFront(nil) : panel.orderFrontRegardless() }

        guard AppSettings.zoomEffect else {
            panel.setFrame(target, display: false)
            order()
            return
        }

        // Start from the selected icon's rect (scale-from-icon), or a slightly
        // smaller centered rect if we couldn't locate it.
        panel.setFrame(iconRect ?? Self.shrunk(target), display: false)
        panel.alphaValue = 0
        order()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = AppSettings.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }
    }

    private func installLocalKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 || event.keyCode == 49 { // esc / space
                self?.close(animated: true)
                return nil
            }
            return event // arrow keys fall through to scroll the list
        }
    }

    @objc private func resigned(_ note: Notification) { close(animated: false) }

    // MARK: - Geometry

    /// Final frame: centered on the screen under the pointer (like system Quick Look).
    private func centeredFrame(size: NSSize) -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2,
            width: size.width, height: size.height
        )
    }

    /// A rect at 88% sharing the same center, for a center-zoom fallback.
    private static func shrunk(_ rect: NSRect) -> NSRect {
        let scale: CGFloat = 0.88
        let w = rect.width * scale, h = rect.height * scale
        return NSRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
    }
}
