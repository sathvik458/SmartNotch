import AppKit
import Carbon.HIToolbox

/// Two system-wide chord hotkeys, registered through Carbon's HotKey API
/// (no CGEventTap, no Input Monitoring permission needed):
///
///   • ⌃⌥ + Space → toggle voice capture (tap once to start, tap again to send)
///   • ⌃⌥ + R     → refresh (cancel current activity and start a fresh recording)
final class HotKeyManager {
    var onToggle: (() -> Void)?
    var onRefresh: (() -> Void)?

    private var toggleRef: EventHotKeyRef?
    private var refreshRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private static let toggleID: UInt32 = 1
    private static let refreshID: UInt32 = 2
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
                    if hkID.id == HotKeyManager.toggleID { mgr.onToggle?() }
                    else if hkID.id == HotKeyManager.refreshID { mgr.onRefresh?() }
                }
                return noErr
            },
            1, &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef)

        let mods: UInt32 = UInt32(controlKey | optionKey)

        var tID = EventHotKeyID(signature: HotKeyManager.signature, id: HotKeyManager.toggleID)
        RegisterEventHotKey(UInt32(kVK_Space), mods, tID,
                            GetApplicationEventTarget(), 0, &toggleRef)

        var rID = EventHotKeyID(signature: HotKeyManager.signature, id: HotKeyManager.refreshID)
        RegisterEventHotKey(UInt32(kVK_ANSI_R), mods, rID,
                            GetApplicationEventTarget(), 0, &refreshRef)
        _ = tID; _ = rID
    }

    deinit {
        if let r = toggleRef { UnregisterEventHotKey(r) }
        if let r = refreshRef { UnregisterEventHotKey(r) }
        if let h = handlerRef { RemoveEventHandler(h) }
    }
}
