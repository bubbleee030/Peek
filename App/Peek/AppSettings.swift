import Foundation

/// Small typed wrapper over UserDefaults for Peek's preferences.
enum AppSettings {
    static let zoomEffectKey = "zoomEffect"

    /// Whether the preview panel animates open with a Quick Look–style zoom.
    /// Defaults to `true` when unset.
    static var zoomEffect: Bool {
        get {
            let defaults = UserDefaults.standard
            return defaults.object(forKey: zoomEffectKey) == nil ? true : defaults.bool(forKey: zoomEffectKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: zoomEffectKey) }
    }
}
