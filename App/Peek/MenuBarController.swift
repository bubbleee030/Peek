import AppKit
import ServiceManagement

@MainActor
final class MenuBarController: NSObject {
    private let keyTap: KeyTap
    private var statusItem: NSStatusItem?
    private let defaults = UserDefaults.standard
    private static let showIconKey = "showMenuBarIcon"

    init(keyTap: KeyTap) {
        self.keyTap = keyTap
        super.init()
        if defaults.object(forKey: Self.showIconKey) == nil {
            defaults.set(true, forKey: Self.showIconKey)
        }
        if defaults.bool(forKey: Self.showIconKey) { installItem() }
    }

    private func installItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Peek")
        statusItem = item
        rebuildMenu()
    }

    func rebuildMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()

        let accessibilityOK = KeyTap.hasAccessibility
        let accItem = NSMenuItem(
            title: accessibilityOK ? "Accessibility: granted" : "Grant Accessibility…",
            action: accessibilityOK ? nil : #selector(grantAccessibility), keyEquivalent: ""
        )
        accItem.target = self
        menu.addItem(accItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let hideItem = NSMenuItem(title: "Hide Menu-Bar Icon", action: #selector(hideIcon), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)

        let quit = NSMenuItem(title: "Quit Peek", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func grantAccessibility() {
        keyTap.requestAccessibility()
        _ = keyTap.start()
        rebuildMenu()
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() }
            else { try service.register() }
        } catch {
            NSLog("Peek: launch-at-login toggle failed: \(error.localizedDescription)")
        }
        rebuildMenu()
    }

    @objc private func hideIcon() {
        defaults.set(false, forKey: Self.showIconKey)
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }
}
