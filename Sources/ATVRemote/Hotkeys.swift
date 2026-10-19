import Carbon.HIToolbox
import AppKit

/// Minimal global-hotkey registrar using the (still-functional, non-sandboxed)
/// Carbon RegisterEventHotKey API — the only real way to get an app-wide
/// shortcut on macOS outside of the Shortcuts/Services system.
/// Replaces Electron's globalShortcut.registerAll([...]).
final class HotkeyManager {
    static let shared = HotkeyManager()
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    var onTrigger: (() -> Void)?

    func registerAll() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, userData in
            guard let eventRef else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
            manager.onTrigger?()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)

        // cmdKey+shiftKey+R, cmdKey+controlKey+R, cmdKey+shiftKey+E, cmdKey+controlKey+E
        let combos: [(UInt32, UInt32)] = [
            (UInt32(kVK_ANSI_R), UInt32(cmdKey | shiftKey)),
            (UInt32(kVK_ANSI_R), UInt32(cmdKey | controlKey)),
            (UInt32(kVK_ANSI_E), UInt32(cmdKey | shiftKey)),
            (UInt32(kVK_ANSI_E), UInt32(cmdKey | controlKey))
        ]
        for (i, combo) in combos.enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x41_54_56_52), id: UInt32(i)) // "ATVR"
            RegisterEventHotKey(combo.0, combo.1, id, GetApplicationEventTarget(), 0, &ref)
            if let ref { hotKeyRefs.append(ref) }
        }
    }

    func unregisterAll() {
        hotKeyRefs.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}
