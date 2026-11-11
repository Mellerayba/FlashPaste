import AppKit
import FlashPasteCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ConfigStore()
    private let hotkeys = HotKeys()
    private var permissionTimer: Timer?
    private(set) var automation: Automation!
    private(set) var menu: StatusMenu!
    private(set) var accessibilityTrusted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let headless = CommandLine.arguments.contains("--headless")
        automation = Automation(config: store.load())
        automation.onChange = { [weak self] in self?.menu.refresh() }
        menu = StatusMenu(app: self)
        registerHotkeys()
        accessibilityTrusted = Permissions.isTrusted(prompt: !headless)
        log("launched; accessibility trusted: \(accessibilityTrusted)")
        if !accessibilityTrusted {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.recheckPermission() }
        }
        menu.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        automation.setEnabled(false)
    }

    private func recheckPermission() {
        guard Permissions.isTrusted(prompt: false) else { return }
        accessibilityTrusted = true
        permissionTimer?.invalidate()
        permissionTimer = nil
        log("accessibility permission granted")
        menu.refresh()
    }

    private func registerHotkeys() {
        hotkeys.register(.toggle, keyCode: 12) { [weak self] in self?.toggleEnabled() }   // Q
        hotkeys.register(.skip, keyCode: 7) { [weak self] in self?.skipPending() }       // X
        hotkeys.register(.reset, keyCode: 15) { [weak self] in self?.resetToTerm() }     // R
        if automation.config[.undoLastPaste] {
            hotkeys.register(.undo, keyCode: 6) { [weak self] in self?.automation.undoLastPaste() } // Z
        } else {
            hotkeys.unregister(.undo)
        }
    }

    // MARK: Actions

    func toggleEnabled() {
        if automation.engine.isEnabled {
            automation.setEnabled(false)
            automation.feedback.show("FlashPaste off")
            return
        }
        guard accessibilityTrusted else {
            log("cannot enable without Accessibility permission")
            explainPermission()
            return
        }
        if automation.setEnabled(true) {
            automation.feedback.show("FlashPaste on · next: \(automation.engine.state.nextField.label)")
        }
    }

    private func explainPermission() {
        let alert = NSAlert()
        alert.messageText = "FlashPaste needs Accessibility access"
        alert.informativeText = "Open System Settings › Privacy & Security › Accessibility. If FlashPaste is already listed, remove it with the minus button first (every rebuild changes its signature), then add build/FlashPaste.app again and switch it on. FlashPaste notices within a few seconds."
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { Permissions.openAccessibilityPane() }
    }

    func skipPending() {
        automation.engine.clearPending()
        automation.feedback.show("Skipped pending capture")
        menu.refresh()
    }

    func resetToTerm() {
        automation.engine.state.reset()
        log("reset to term")
        automation.feedback.show("Next field: term")
        menu.refresh()
    }

    func setToggle(_ toggle: Toggle, _ value: Bool) {
        var config = automation.config
        config[toggle] = value
        log("preference \(toggle.rawValue) = \(value)")
        apply(config, save: true)
    }

    private func apply(_ config: Config, save: Bool) {
        let watchedAppsChanged = config.quizletApps != automation.config.quizletApps
        automation.config = config
        if save { store.save(config) }
        registerHotkeys()
        if watchedAppsChanged, automation.engine.isEnabled {
            automation.setEnabled(false)
            automation.setEnabled(true)
        }
        menu.refresh()
    }

    func reloadConfig() {
        apply(store.load(), save: false)
        automation.feedback.show("Config reloaded")
    }

    func openConfig() {
        if !FileManager.default.fileExists(atPath: store.url.path) { store.save(automation.config) }
        NSWorkspace.shared.open(store.url)
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            log("launch at login: \(on)")
        } catch {
            log("launch at login failed (run from the built .app bundle): \(error.localizedDescription)")
        }
        menu.refresh()
    }
}
