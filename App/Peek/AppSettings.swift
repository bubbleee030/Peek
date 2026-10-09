import Foundation
import QuartzCore

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

    /// Open/close timing, matched to native Quick Look (measured on macOS 27)
    /// so the two read as one motion when Peek hands off to it and back.
    /// Opening shoots out of the icon and settles (~half size within a frame);
    /// closing accelerates into the icon, fading over its second half.
    enum Animation {
        static let openDuration: TimeInterval = 0.3
        static var openTiming: CAMediaTimingFunction { CAMediaTimingFunction(controlPoints: 0.1, 0.85, 0.2, 1) }
        static let openFadeDuration: TimeInterval = 0.05
        static let closeDuration: TimeInterval = 0.2
        static var closeTiming: CAMediaTimingFunction { CAMediaTimingFunction(name: .easeIn) }
        static var closeFadeTiming: CAMediaTimingFunction { CAMediaTimingFunction(controlPoints: 0.6, 0, 1, 1) }
    }
}
