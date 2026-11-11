import AppKit
import ApplicationServices
import FlashPasteCore

enum Permissions {
    static func isTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilityPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

enum AX {
    static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func focusedWindow(pid: pid_t) -> AXUIElement? {
        guard let value = attribute(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    static func windows(pid: pid_t) -> [AXUIElement] {
        attribute(AXUIElementCreateApplication(pid), kAXWindowsAttribute) as? [AXUIElement] ?? []
    }

    static func title(_ window: AXUIElement) -> String? {
        attribute(window, kAXTitleAttribute) as? String
    }
}

/// Fires `onFocusChange` when one of the given apps activates or changes its focused window / window title.
final class FocusWatcher: Invalidatable {
    private let bundleIDs: [String]
    private let onFocusChange: () -> Void
    private var observers: [pid_t: AXObserver] = [:]
    private var tokens: [NSObjectProtocol] = []

    init(bundleIDs: [String], onFocusChange: @escaping () -> Void) {
        self.bundleIDs = bundleIDs
        self.onFocusChange = onFocusChange
        let center = NSWorkspace.shared.notificationCenter
        tokens.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let app = self.app(from: note), self.bundleIDs.contains(app.bundleIdentifier ?? "") else { return }
            self.attach(pid: app.processIdentifier)
            self.onFocusChange()
        })
        tokens.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let app = self.app(from: note) else { return }
            self.detach(pid: app.processIdentifier)
        })
        for app in NSWorkspace.shared.runningApplications where bundleIDs.contains(app.bundleIdentifier ?? "") {
            attach(pid: app.processIdentifier)
        }
    }

    private func app(from note: Notification) -> NSRunningApplication? {
        note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    }

    private func attach(pid: pid_t) {
        guard observers[pid] == nil else { return }
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            Unmanaged<FocusWatcher>.fromOpaque(refcon).takeUnretainedValue().onFocusChange()
        }
        var observer: AXObserver?
        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else {
            log("AXObserver creation failed for pid \(pid)")
            return
        }
        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification, kAXTitleChangedNotification] {
            AXObserverAddNotification(observer, appElement, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
        log("watching focus of pid \(pid)")
    }

    private func detach(pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    func invalidate() {
        tokens.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        tokens = []
        observers.keys.forEach(detach)
        log("focus watcher removed")
    }
}
