import AppKit
import FlashPasteCore

/// The capture-and-paste loop: event tap -> Cmd+C -> pending -> Quizlet focus -> Cmd+V + Tabs.
final class Automation {
    var config: Config { didSet { feedback.enabled = config[.captureFeedback] } }
    let feedback = Feedback()
    var onChange: (() -> Void)?

    private(set) lazy var engine = Engine { [unowned self] in self.makeResources() }
    private var timers = TimerBag()
    private var sourceWindow: AXUIElement?
    private var pasting = false

    private let captureDebounce = 0.08
    private let clipboardDelay = 0.10
    private let tabDelay = 0.15
    private let tabGap = 0.05

    init(config: Config) {
        self.config = config
        feedback.enabled = config[.captureFeedback]
        engine.log = { log($0) }
    }

    // MARK: Lifecycle

    private func makeResources() -> [Invalidatable]? {
        guard let tap = EventTap(onTrigger: { [weak self] trigger in self?.triggered(trigger) }) else { return nil }
        let watcher = FocusWatcher(bundleIDs: config.quizletApps) { [weak self] in self?.focusChanged() }
        timers = TimerBag()
        return [tap, watcher, timers]
    }

    @discardableResult
    func setEnabled(_ on: Bool) -> Bool {
        defer { onChange?() }
        if on { return engine.enable() }
        engine.disable()
        sourceWindow = nil
        pasting = false
        return true
    }

    // MARK: Capture

    private func triggered(_ trigger: EventTap.Trigger) {
        guard engine.isEnabled, !pasting,
              let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier, config.sourceApps.contains(bundleID) else { return }
        timers.schedule("capture", after: captureDebounce) { [weak self] in self?.capture(from: app) }
    }

    private func capture(from app: NSRunningApplication) {
        guard engine.isEnabled, let bundleID = app.bundleIdentifier else { return }
        if config[.autoPause], !quizletWindowExists() { return }
        let pid = app.processIdentifier
        let window = AX.focusedWindow(pid: pid)
        if config.quizletApps.contains(bundleID), PasteDecision.titleMatches(window.flatMap(AX.title), config) {
            return // never copy from the Quizlet window itself
        }
        let before = NSPasteboard.general.changeCount
        Keystrokes.post(.c, flags: .maskCommand, to: pid)
        timers.schedule("read", after: clipboardDelay) { [weak self] in
            guard let self else { return }
            let pasteboard = NSPasteboard.general
            guard pasteboard.changeCount != before else { log("capture: clipboard unchanged, ignoring"); return }
            guard let text = pasteboard.string(forType: .string),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                log("capture: empty text, ignoring")
                return
            }
            self.engine.setPending(text)
            self.sourceWindow = window
            self.feedback.show("Captured: " + preview(text))
            self.onChange?()
        }
    }

    private func quizletWindowExists() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            guard let bundleID = app.bundleIdentifier, config.quizletApps.contains(bundleID) else { return false }
            return AX.windows(pid: app.processIdentifier).contains { PasteDecision.titleMatches(AX.title($0), config) }
        }
    }

    // MARK: Paste

    private struct Front {
        let app: NSRunningApplication
        let window: AXUIElement?
        var title: String? { window.flatMap(AX.title) }
    }

    private func front() -> Front? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return Front(app: app, window: AX.focusedWindow(pid: app.processIdentifier))
    }

    private func isQuizletFront(_ front: Front) -> Bool {
        config.quizletApps.contains(front.app.bundleIdentifier ?? "") && PasteDecision.titleMatches(front.title, config)
    }

    private func focusChanged() {
        guard engine.isEnabled, engine.pending != nil, !pasting, let front = front() else { return }
        let isSource = sourceWindow.map { source in front.window.map { CFEqual(source, $0) } ?? false } ?? false
        let context = PasteContext(pending: engine.pending, appBundleID: front.app.bundleIdentifier,
                                   windowTitle: front.title, isSourceWindow: isSource, enabled: engine.isEnabled)
        guard PasteDecision.shouldPaste(context, config: config) else { return }
        pasting = true
        log("Quizlet window focused; pasting after \(config.focusDelay)s")
        let pid = front.app.processIdentifier
        timers.schedule("paste", after: config.focusDelay) { [weak self] in self?.performPaste(pid: pid) }
    }

    private func performPaste(pid: pid_t) {
        guard let raw = engine.pending, let front = front(), front.app.processIdentifier == pid, isQuizletFront(front) else {
            pasting = false
            log("paste aborted: focus moved away")
            return
        }
        let text = TextCleaner.clean(raw, options: config.cleanOptions)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        engine.clearPending()
        let record = engine.state.didPaste(config: config)
        Keystrokes.post(.v, flags: .maskCommand, to: pid)
        timers.schedule("tabs", after: tabDelay) { [weak self] in self?.sendTabs(record.tabs, to: pid) }
        let next = engine.state.nextField.label
        log("pasted \(record.field.label) (\(text.count) chars) + \(record.tabs) tab(s); next: \(next)")
        feedback.show("Pasted \(record.field.label) → next: \(next)")
        onChange?()
    }

    /// Posts `count` Tabs one at a time so a web page sees each as a separate key press.
    private func sendTabs(_ count: Int, to pid: pid_t) {
        guard count > 0 else { pasting = false; return }
        Keystrokes.post(.tab, to: pid)
        timers.schedule("tabs", after: tabGap) { [weak self] in self?.sendTabs(count - 1, to: pid) }
    }

    // MARK: Extras

    /// Reverses the last paste: Shift+Tab back into the field, select all, delete, step the state back.
    func undoLastPaste() {
        guard engine.isEnabled, !pasting, let front = front(), isQuizletFront(front) else {
            feedback.show("Undo: Quizlet window is not focused")
            return
        }
        guard let record = engine.state.undo() else { feedback.show("Nothing to undo"); return }
        let pid = front.app.processIdentifier
        for _ in 0..<record.tabs { Keystrokes.post(.tab, flags: .maskShift, to: pid) }
        timers.schedule("undo", after: tabDelay) {
            Keystrokes.post(.a, flags: .maskCommand, to: pid)
            Keystrokes.post(.delete, to: pid)
        }
        log("undid last \(record.field.label) paste; next: \(engine.state.nextField.label)")
        feedback.show("Undid \(record.field.label) paste")
        onChange?()
    }

    func requeue(_ text: String) {
        engine.setPending(text)
        sourceWindow = nil
        feedback.show("Re-queued: " + preview(text))
        onChange?()
    }
}
