import Carbon

/// Global hotkeys via Carbon RegisterEventHotKey. Handlers run on the main thread.
final class HotKeys {
    enum ID: UInt32 { case toggle = 1, skip, reset, undo }
    static let modifiers = UInt32(controlKey | optionKey)

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var handlerRef: EventHandlerRef?

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            Unmanaged<HotKeys>.fromOpaque(userData).takeUnretainedValue().handlers[hotKeyID.id]?()
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec,
                            Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    func register(_ id: ID, keyCode: UInt32, handler: @escaping () -> Void) {
        unregister(id)
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4650_5354), id: id.rawValue) // "FPST"
        let status = RegisterEventHotKey(keyCode, HotKeys.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { log("hotkey \(id) registration failed (\(status))"); return }
        refs[id.rawValue] = ref
        handlers[id.rawValue] = handler
    }

    func unregister(_ id: ID) {
        if let ref = refs.removeValue(forKey: id.rawValue) { UnregisterEventHotKey(ref) }
        handlers[id.rawValue] = nil
    }
}
