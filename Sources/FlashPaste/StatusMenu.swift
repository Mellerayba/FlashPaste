import AppKit
import FlashPasteCore
import ServiceManagement

/// The menu-bar item and its menu. State is refreshed every time the menu opens.
final class StatusMenu: NSObject, NSMenuDelegate {
    private unowned let app: AppDelegate
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "q")
    private let infoItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let skipItem = NSMenuItem(title: "Skip pending capture", action: #selector(skip), keyEquivalent: "x")
    private let resetItem = NSMenuItem(title: "Reset to term", action: #selector(reset), keyEquivalent: "r")
    private let undoItem = NSMenuItem(title: "Undo last paste", action: #selector(undo), keyEquivalent: "z")
    private let historyItem = NSMenuItem(title: "Capture history", action: nil, keyEquivalent: "")
    private let prefsItem = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
    private let launchItem = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let grantItem = NSMenuItem(title: "Grant Accessibility access…", action: #selector(grant), keyEquivalent: "")

    init(app: AppDelegate) {
        self.app = app
        super.init()
        item.button?.image = StatusMenu.loadIcon()
        item.button?.toolTip = "FlashPaste"
        menu.delegate = self
        for hotkeyItem in [enabledItem, skipItem, resetItem, undoItem] { hotkeyItem.keyEquivalentModifierMask = [.control, .option] }
        infoItem.isEnabled = false
        historyItem.submenu = NSMenu()
        prefsItem.submenu = NSMenu()
        for toggle in Toggle.allCases {
            let toggleItem = NSMenuItem(title: toggle.title, action: #selector(togglePreference(_:)), keyEquivalent: "")
            toggleItem.representedObject = toggle.rawValue
            prefsItem.submenu?.addItem(toggleItem)
        }
        let items: [NSMenuItem] = [
            enabledItem, infoItem, skipItem, resetItem, undoItem, historyItem, .separator(),
            prefsItem,
            NSMenuItem(title: "Open config file", action: #selector(openConfig), keyEquivalent: ""),
            NSMenuItem(title: "Reload config", action: #selector(reloadConfig), keyEquivalent: ""),
            .separator(),
            launchItem, grantItem,
            NSMenuItem(title: "Quit FlashPaste", action: #selector(quit), keyEquivalent: ""),
        ]
        for menuItem in items { menu.addItem(menuItem) }
        for menuItem in menu.items + prefsItem.submenu!.items where menuItem.action != nil { menuItem.target = self }
        item.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    func refresh() {
        let automation = app.automation!
        let config = automation.config
        let enabled = automation.engine.isEnabled
        enabledItem.state = enabled ? .on : .off
        item.button?.appearsDisabled = !enabled
        let pending = automation.engine.pending.map { preview($0) } ?? "none"
        infoItem.title = "Next: \(automation.engine.state.nextField.label) · Pending: \(pending)"
        skipItem.isEnabled = automation.engine.pending != nil
        undoItem.isHidden = !config[.undoLastPaste]
        historyItem.isHidden = !config[.captureHistory]
        if let history = historyItem.submenu {
            history.removeAllItems()
            for text in automation.engine.history {
                let historyEntry = NSMenuItem(title: preview(text, limit: 50), action: #selector(requeue(_:)), keyEquivalent: "")
                historyEntry.representedObject = text
                historyEntry.target = self
                history.addItem(historyEntry)
            }
            if history.items.isEmpty { history.addItem(NSMenuItem(title: "No captures yet", action: nil, keyEquivalent: "")) }
        }
        for toggleItem in prefsItem.submenu?.items ?? [] {
            if let raw = toggleItem.representedObject as? String, let toggle = Toggle(rawValue: raw) {
                toggleItem.state = config[toggle] ? .on : .off
            }
        }
        launchItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        grantItem.isHidden = app.accessibilityTrusted
    }

    // MARK: Actions

    @objc private func toggleEnabled() { app.toggleEnabled() }
    @objc private func skip() { app.skipPending() }
    @objc private func reset() { app.resetToTerm() }
    @objc private func undo() { app.automation.undoLastPaste() }
    @objc private func openConfig() { app.openConfig() }
    @objc private func reloadConfig() { app.reloadConfig() }
    @objc private func grant() { Permissions.openAccessibilityPane() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func toggleLaunchAtLogin() { app.setLaunchAtLogin(SMAppService.mainApp.status != .enabled) }

    @objc private func requeue(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String { app.automation.requeue(text) }
    }

    @objc private func togglePreference(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let toggle = Toggle(rawValue: raw) else { return }
        app.setToggle(toggle, !app.automation.config[toggle])
    }

    private static func loadIcon() -> NSImage {
        let image: NSImage
        if let url = Bundle.main.url(forResource: "menubar", withExtension: "pdf"), let pdf = NSImage(contentsOf: url) {
            image = pdf
        } else {
            image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "FlashPaste") ?? NSImage()
        }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}
