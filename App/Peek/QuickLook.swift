import AppKit
@preconcurrency import CoreGraphics

/// Triggers macOS's built-in Quick Look by synthesizing a spacebar press.
/// Used when the user navigates onto a file Peek can't preview: Peek closes
/// its own panel and lets the system preview take over.
@MainActor
enum QuickLook {
    private static let spaceKeyCode: CGKeyCode = 49

    static func trigger() {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: spaceKeyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: spaceKeyCode, keyDown: false) else { return }
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}
