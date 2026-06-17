import AppKit
import Carbon.HIToolbox

/// Three system-wide Carbon hotkeys (no Input Monitoring needed):
///
///   • ⌃⌥ + Space → toggle voice capture (tap to record, tap to send)
///   • ⌃⌥ + Q     → rapid mode: same toggle, but the next answer is 1–3 lines
///   • ⌃⌥ + R     → refresh: cancel current activity, start a fresh recording
final class HotKeyManager {
    var onToggle: (() -> Void)?
    var onRapid: (() -> Void)?
    var onRefresh: (() -> Void)?

    private var toggleRef: EventHotKeyRef?
    private var rapidRef: EventHotKeyRef?
    private var refreshRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private static let toggleID:  UInt32 = 1
    private static let refreshID: UInt32 = 2
    private static let rapidID:   UInt32 = 3
    private static let signature = OSType(0x534E5443) // 'SNTC'

    func start() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData -> OSStatus in
                guard let eventRef = eventRef, let userData = userData else { return noErr }
                var hkID = EventHotKeyID()
                let size = MemoryLayout<EventHotKeyID>.size
                GetEventParameter(eventRef,
                                  EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID),
                                  nil, size, nil, &hkID)
                let mgr = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    switch hkID.id {
                    case HotKeyManager.toggleID:  mgr.onToggle?()
                    case HotKeyManager.refreshID: mgr.onRefresh?()
                    case HotKeyManager.rapidID:   mgr.onRapid?()
                    default: break
                    }
                }
                return noErr
            },
            1, &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef)

        let mods = UInt32(controlKey | optionKey)
        let target = GetApplicationEventTarget()

        var tID = EventHotKeyID(signature: HotKeyManager.signature, id: HotKeyManager.toggleID)
        RegisterEventHotKey(UInt32(kVK_Space), mods, tID, target, 0, &toggleRef)

        var rID = EventHotKeyID(signature: HotKeyManager.signature, id: HotKeyManager.refreshID)
        RegisterEventHotKey(UInt32(kVK_ANSI_R), mods, rID, target, 0, &refreshRef)

        var qID = EventHotKeyID(signature: HotKeyManager.signature, id: HotKeyManager.rapidID)
        RegisterEventHotKey(UInt32(kVK_ANSI_Q), mods, qID, target, 0, &rapidRef)
        _ = tID; _ = rID; _ = qID
    }

    deinit {
        if let r = toggleRef  { UnregisterEventHotKey(r) }
        if let r = refreshRef { UnregisterEventHotKey(r) }
        if let r = rapidRef   { UnregisterEventHotKey(r) }
        if let h = handlerRef { RemoveEventHandler(h) }
    }
}
