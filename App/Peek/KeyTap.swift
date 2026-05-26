import AppKit
@preconcurrency import ApplicationServices
@preconcurrency import CoreGraphics

@MainActor
final class KeyTap {
    private let finder: FinderContext
    private let onPreview: (URL) -> Void
    private let isPreviewOpen: () -> Bool
    private let onClosePreview: () -> Void
    private let focusGuard = FocusGuard()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private static let spaceKeyCode: Int64 = 49
    private static let escKeyCode: Int64 = 53

    init(finder: FinderContext,
         isPreviewOpen: @escaping () -> Bool,
         onPreview: @escaping (URL) -> Void,
         onClosePreview: @escaping () -> Void) {
        self.finder = finder
        self.isPreviewOpen = isPreviewOpen
        self.onPreview = onPreview
        self.onClosePreview = onClosePreview
    }

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    @discardableResult
    func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Returns false if Accessibility isn't granted yet (after prompting).
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        guard Self.hasAccessibility else { requestAccessibility(); return false }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<KeyTap>.fromOpaque(refcon).takeUnretainedValue()
                return MainActor.assumeIsolated { me.handle(type: type, event: event) }
            },
            userInfo: refcon
        ) else {
            NSLog("Peek: failed to create event tap")
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let passthrough = Unmanaged.passUnretained(event)

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return passthrough
        }
        guard type == .keyDown else { return passthrough }
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keycode == Self.spaceKeyCode || keycode == Self.escKeyCode else {
            return passthrough // arrows etc. flow to Finder untouched
        }
        // Only act while Finder is frontmost and not editing text (e.g. renaming).
        // In preview-scroll mode the panel is key (Peek is frontmost), so this
        // guard fails and that mode's own local monitor handles space/esc.
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else { return passthrough }
        guard !focusGuard.isEditingText else { return passthrough }

        // Panel already open (Finder-navigation mode): space or esc closes it.
        if isPreviewOpen() {
            onClosePreview()
            return nil
        }

        guard keycode == Self.spaceKeyCode else { return passthrough } // bare esc does nothing
        // Plain space only — let shortcuts through.
        let modifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
        guard event.flags.intersection(modifiers).isEmpty else { return passthrough }
        guard let url = finder.previewableSelection else { return passthrough } // non-folder → native QL

        onPreview(url)
        return nil // consume — native Quick Look does not open
    }
}
