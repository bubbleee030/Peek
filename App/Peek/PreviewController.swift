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

        let target = centeredFrame(for: panel)
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)

        if AppSettings.zoomEffect {
            // Quick Look–style zoom: start slightly smaller and transparent,
            // then spring out to the final centered frame.
            panel.setFrame(start(from: target), display: false)
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(target, display: true)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.setFrame(target, display: false)
            panel.makeKeyAndOrderFront(nil)
        }
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

    /// Final frame: centered on the screen the pointer is on (falling back to the
    /// main screen), like the system Quick Look panel.
    private func centeredFrame(for panel: NSPanel) -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = panel.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        return NSRect(origin: origin, size: size)
    }

    /// A slightly smaller rect sharing the same center, for the zoom-in start.
    private func start(from target: NSRect) -> NSRect {
        let scale: CGFloat = 0.92
        let w = target.width * scale
        let h = target.height * scale
        return NSRect(x: target.midX - w / 2, y: target.midY - h / 2, width: w, height: h)
    }
}
