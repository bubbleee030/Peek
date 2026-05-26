import AppKit
import SwiftUI

@MainActor
final class PreviewController {
    private var panel: NSPanel?
    private var keyMonitor: Any?

    func show(url: URL) {
        close()

        let model = PreviewViewModel(url: url)
        let hosting = NSHostingView(rootView: PreviewView(model: model))

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 440),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.contentView = hosting
        positionNearMouse(panel)

        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        model.load()

        // Esc or space closes; click-away (resignKey) closes.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 || event.keyCode == 49 { // esc / space
                self?.close()
                return nil
            }
            return event
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(resigned(_:)),
            name: NSWindow.didResignKeyNotification, object: panel
        )
    }

    @objc private func resigned(_ note: Notification) { close() }

    func close() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if let panel {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: panel)
            panel.orderOut(nil)
        }
        panel = nil
    }

    private func positionNearMouse(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { panel.center(); return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: min(max(mouse.x - size.width / 2, visible.minX), visible.maxX - size.width),
            y: min(max(mouse.y - size.height / 2, visible.minY), visible.maxY - size.height)
        )
        panel.setFrameOrigin(origin)
    }
}
