import AppKit
@preconcurrency import ApplicationServices

/// Best-effort lookup of the currently selected Finder item's on-screen icon
/// rect, used as the origin for the Quick Look–style "scale from the icon"
/// animation.
@MainActor
enum IconLocator {
    /// Rect of the selected item named `name` in Cocoa screen coordinates
    /// (bottom-left origin), or `nil` if it can't be located (Peek then falls
    /// back to a center zoom).
    ///
    /// Finder exposes a selected row in both the sidebar and the file view, and
    /// in list/column views that row spans the full width — so we match by the
    /// previewed file's name, prefer the main file area over the sidebar, and
    /// reduce wide rows to an icon-sized square at their leading edge.
    static func selectedItemRect(matching name: String) -> NSRect? {
        guard let finder = finderElement(),
              let window = element(finder, kAXFocusedWindowAttribute) else { return nil }

        let candidates = selectedDescendants(of: window)
        guard !candidates.isEmpty else { return nil }

        let sidebarMaxX = (axFrame(window)?.minX ?? 0) + 240
        func isMain(_ element: AXUIElement) -> Bool {
            guard let f = axFrame(element) else { return false }
            return f.midX > sidebarMaxX
        }

        let target = name.lowercased()
        let targetNoExt = (name as NSString).deletingPathExtension.lowercased()
        let nameMatches = candidates.filter { element in
            displayStrings(of: element).contains { $0 == target || $0 == targetNoExt }
        }

        // Prefer: a name match in the main area → any name match → the largest
        // selected element in the main area.
        let chosen = nameMatches.first(where: isMain)
            ?? nameMatches.first
            ?? candidates.filter(isMain).max { area($0) < area($1) }

        guard let chosen, let rect = axFrame(chosen) else { return nil }
        return cocoa(iconProxy(rect))
    }

    private static func finderElement() -> AXUIElement? {
        guard let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.finder" }) else { return nil }
        return AXUIElementCreateApplication(app.processIdentifier)
    }

    /// Every selected row/child anywhere under `root` (bounded BFS).
    private static func selectedDescendants(of root: AXUIElement) -> [AXUIElement] {
        var found: [AXUIElement] = []
        var queue = [root]
        var visited = 0
        while !queue.isEmpty, visited < 400 {
            let node = queue.removeFirst()
            visited += 1
            if let rows = elements(node, kAXSelectedRowsAttribute) { found += rows }
            if let sel = elements(node, "AXSelectedChildren") { found += sel }
            if let children = elements(node, kAXChildrenAttribute) { queue += children }
        }
        return found
    }

    /// Lowercased display strings for an element and its descendants (bounded),
    /// so a selected row matches the previewed file even when the name lives in
    /// a nested cell/static-text.
    private static func displayStrings(of element: AXUIElement) -> Set<String> {
        var result = Set<String>()
        var queue: [(AXUIElement, Int)] = [(element, 0)]
        var visited = 0
        while !queue.isEmpty, visited < 40 {
            let (node, depth) = queue.removeFirst()
            visited += 1
            for attr in [kAXTitleAttribute as String, kAXValueAttribute as String,
                         kAXDescriptionAttribute as String, "AXFilename"] {
                if let s = string(node, attr) { result.insert(s.lowercased()) }
            }
            if depth < 3, let children = elements(node, kAXChildrenAttribute) {
                for child in children.prefix(12) { queue.append((child, depth + 1)) }
            }
        }
        return result
    }

    // MARK: - Geometry

    private static func area(_ element: AXUIElement) -> CGFloat {
        guard let f = axFrame(element) else { return 0 }
        return f.width * f.height
    }

    /// Wide list/column rows have their icon at the leading edge; zoom from a
    /// square there instead of the whole row (which reads as a center zoom).
    private static func iconProxy(_ rect: CGRect) -> CGRect {
        guard rect.width > rect.height * 2.5 else { return rect }
        let side = min(rect.height, 32)
        return CGRect(x: rect.minX, y: rect.minY + (rect.height - side) / 2, width: side, height: side)
    }

    private static func axFrame(_ element: AXUIElement) -> CGRect? {
        guard let position = point(element, kAXPositionAttribute),
              let size = size(element, kAXSizeAttribute) else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// AX frames are global with a top-left origin; convert to Cocoa bottom-left,
    /// measured from the primary display that owns the menu bar.
    private static func cocoa(_ axRect: CGRect) -> NSRect {
        let primaryHeight = (NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main)?.frame.height ?? 0
        return NSRect(x: axRect.minX, y: primaryHeight - axRect.minY - axRect.height,
                      width: axRect.width, height: axRect.height)
    }

    // MARK: - AX helpers

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let value = ref, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func elements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement]? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let value = ref, CFGetTypeID(value) == CFArrayGetTypeID() else { return nil }
        let items = value as! [AnyObject]
        let result = items.compactMap { item -> AXUIElement? in
            CFGetTypeID(item) == AXUIElementGetTypeID() ? (item as! AXUIElement) : nil
        }
        return result.isEmpty ? nil : result
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let value = ref, CFGetTypeID(value) == CFStringGetTypeID() else { return nil }
        let s = value as! String
        return s.isEmpty ? nil : s
    }

    private static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let value = axValue(element, attribute) else { return nil }
        var out = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &out) ? out : nil
    }

    private static func size(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let value = axValue(element, attribute) else { return nil }
        var out = CGSize.zero
        return AXValueGetValue(value, .cgSize, &out) ? out : nil
    }

    private static func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let value = ref, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }
}
