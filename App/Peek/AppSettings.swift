import Foundation

/// Small typed wrapper over UserDefaults for Peek's preferences.
enum AppSettings {
    static let zoomEffectKey = "zoomEffect"
    static let arrowModeKey = "arrowMode"

    /// What the arrow keys do while a preview is open.
    enum ArrowMode: String {
        /// Quick Look style: arrows move the Finder selection; Peek follows live.
        case finderNavigation
        /// Arrows scroll the contents list inside Peek's panel.
        case previewScroll
    }

    /// Whether the preview panel animates open with a Quick Look–style zoom.
    /// Defaults to `true` when unset.
    static var zoomEffect: Bool {
        get {
            let defaults = UserDefaults.standard
            return defaults.object(forKey: zoomEffectKey) == nil ? true : defaults.bool(forKey: zoomEffectKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: zoomEffectKey) }
    }

    /// Arrow-key behavior. Defaults to Finder-navigation (Quick Look style).
    static var arrowMode: ArrowMode {
        get { ArrowMode(rawValue: UserDefaults.standard.string(forKey: arrowModeKey) ?? "") ?? .finderNavigation }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: arrowModeKey) }
    }

    /// Open/close animation length. Mirrors the system Quick Look default of
    /// ~0.2s, honoring the user's global `QLPanelAnimationDuration` if they set one.
    static var animationDuration: TimeInterval {
        let v = UserDefaults.standard.double(forKey: "QLPanelAnimationDuration")
        return v > 0 ? v : 0.2
    }
}
