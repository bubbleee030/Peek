import AppKit
@preconcurrency import CoreGraphics

/// Drives macOS's built-in Quick Look by synthesizing key presses, so Peek and
/// the system preview can hand off to each other as the Finder selection moves.
@MainActor
enum QuickLook {
    private static let spaceKeyCode: CGKeyCode = 49

    /// Stamped on every key event Peek synthesizes so its own tap lets it through.
    static let syntheticEventMarker: Int64 = 0x5045_454B // "PEEK"

    /// Opens native Quick Look on the current Finder selection.
    static func trigger() { post(spaceKeyCode) }

    /// Closes native Quick Look. Space toggles it from Finder's browser window
    /// too, whereas Esc only works while the Quick Look panel itself has focus.
    static func dismiss() { post(spaceKeyCode) }

    /// Whether native Quick Look's panel is on screen. Finder hosts it as a
    /// floating-level window; its normal browser windows sit at level 0. After
    /// closing it lingers ~150ms fully transparent, so that counts as gone.
    static var isVisible: Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        let floating = Int(CGWindowLevelForKey(.floatingWindow))
        return windows.contains {
            $0[kCGWindowOwnerName as String] as? String == "Finder"
                && $0[kCGWindowLayer as String] as? Int == floating
                && (($0[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1) > 0.05
        }
    }

    private static func post(_ key: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else { return }
        for event in [down, up] {
            event.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
            event.post(tap: .cgSessionEventTap)
        }
    }
}
