import AppKit
import Carbon.HIToolbox

@MainActor
final class GlobalShortcuts {
    private var handler: EventHandlerRef?
    private var registrations: [EventHotKeyRef] = []
    private let action: (ShortcutAction) -> Void

    init(action: @escaping (ShortcutAction) -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var key = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &key)
            guard result == noErr, key.signature == 0x4B414E54,
                  ShortcutAction.allCases.indices.contains(Int(key.id)) else { return OSStatus(eventNotHandledErr) }
            let shortcuts = Unmanaged<GlobalShortcuts>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { shortcuts.action(ShortcutAction.allCases[Int(key.id)]) }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    func configure(_ shortcuts: [String: Shortcut]) -> [String] {
        registrations.forEach { UnregisterEventHotKey($0) }
        registrations.removeAll()
        var failures: [String] = []
        for (index, action) in ShortcutAction.allCases.enumerated() {
            guard let shortcut = shortcuts[action.rawValue] else { continue }
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: 0x4B414E54, id: UInt32(index))
            let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id,
                                             GetApplicationEventTarget(), 0, &ref)
            if result == noErr, let ref {
                registrations.append(ref)
            } else {
                failures.append(action.rawValue)
            }
        }
        return failures
    }

    deinit {
        registrations.forEach { UnregisterEventHotKey($0) }
        if let handler { RemoveEventHandler(handler) }
    }
}
