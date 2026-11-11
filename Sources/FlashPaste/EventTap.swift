import AppKit
import FlashPasteCore

/// Listen-only CGEventTap for left-mouse-up and shift+arrow key-up.
final class EventTap: Invalidatable {
    enum Trigger { case mouseUp, shiftArrow }

    private let onTrigger: (Trigger) -> Void
    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    init?(onTrigger: @escaping (Trigger) -> Void) {
        self.onTrigger = onTrigger
        let mask: CGEventMask = (1 << CGEventType.leftMouseUp.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if let refcon {
                Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                           eventsOfInterest: mask, callback: callback,
                                           userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            log("event tap creation failed (missing Accessibility permission?)")
            return nil
        }
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
        log("event tap created")
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let port { CGEvent.tapEnable(tap: port, enable: true); log("event tap re-enabled") }
        case .leftMouseUp:
            onTrigger(.mouseUp)
        case .keyUp:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if (123...126).contains(keyCode), event.flags.contains(.maskShift) { onTrigger(.shiftArrow) }
        default:
            break
        }
    }

    func invalidate() {
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(port)
        self.port = nil
        self.source = nil
        log("event tap removed")
    }
}

/// Posts synthetic key presses directly to a process.
enum Keystrokes {
    enum Key: CGKeyCode { case a = 0, c = 8, v = 9, tab = 48, delete = 51 }

    static func post(_ key: Key, flags: CGEventFlags = [], to pid: pid_t) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: down) else { continue }
            event.flags = flags
            event.postToPid(pid)
        }
    }
}

/// Cancellable main-queue timers, torn down together on disable.
final class TimerBag: Invalidatable {
    private var items: [String: DispatchWorkItem] = [:]

    /// Scheduling the same name again cancels the earlier one (trailing debounce).
    func schedule(_ name: String, after seconds: Double, _ block: @escaping () -> Void) {
        items[name]?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.items[name] = nil
            block()
        }
        items[name] = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    func invalidate() {
        items.values.forEach { $0.cancel() }
        items = [:]
    }
}
