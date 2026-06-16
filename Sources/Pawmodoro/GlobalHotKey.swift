import AppKit
import Carbon.HIToolbox

/// A system-wide hotkey registered through the Carbon Event Manager.
///
/// Deliberately *not* an `NSEvent` global monitor: that would require the
/// Input-Monitoring permission, which would break ADR-0001's promise that
/// Pawmodoro needs no special permissions. `RegisterEventHotKey` is permission-
/// free and fires regardless of which app is focused — exactly what the
/// Emergency Shoo needs, since Pawmodoro never holds key focus during a Rest.
@MainActor
final class GlobalHotKey {
    // nonisolated(unsafe): plain C handles, touched only here and in deinit
    // (which runs exclusively), so there is no concurrent access to guard.
    private nonisolated(unsafe) var hotKeyRef: EventHotKeyRef?
    private nonisolated(unsafe) var handlerRef: EventHandlerRef?
    private let onFire: () -> Void

    /// Registers the hotkey. `keyCode` is a Carbon virtual key code (e.g.
    /// `kVK_ANSI_Period`); `modifiers` is a Carbon mask (e.g.
    /// `controlKey | optionKey | cmdKey`). Returns `nil` if registration fails.
    init?(keyCode: UInt32, modifiers: UInt32, onFire: @escaping () -> Void) {
        self.onFire = onFire

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // The C callback can't capture, so route through an opaque self pointer.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let install = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                // Carbon dispatches hotkey events on the main run loop.
                MainActor.assumeIsolated {
                    Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue().onFire()
                }
                return noErr
            },
            1, &eventType, selfPtr, &handlerRef
        )
        guard install == noErr else { return nil }

        let id = EventHotKeyID(signature: OSType(0x5041_5753 /* 'PAWS' */), id: 1)
        let register = RegisterEventHotKey(
            keyCode, modifiers, id, GetEventDispatcherTarget(), 0, &hotKeyRef
        )
        guard register == noErr else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            return nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
