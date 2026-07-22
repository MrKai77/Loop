import Carbon.HIToolbox

/// A Loop key chord in the shape accepted by Carbon's `RegisterEventHotKey` API.
///
/// Loop normally observes shortcuts through a `CGEventTap`, but macOS stops delivering ordinary
/// key events to that tap while Secure Input is active. Carbon hotkeys keep working in that state,
/// so representable shortcuts are registered through both paths. Carbon accepts exactly one
/// ordinary virtual key plus a side-independent modifier mask; more complex Loop chords remain on
/// the event-tap path.
struct SystemHotKeyShortcut: Hashable {
    /// The one non-modifier virtual key passed to Carbon.
    let keyCode: CGKeyCode

    /// Carbon's bitmask representation of the shortcut modifiers.
    let modifiers: UInt32

    /// The normalized Loop representation used to match and deduplicate event-tap input.
    let keyCodes: Set<CGKeyCode>

    /// Converts a Loop key set into Carbon's restricted hotkey representation.
    ///
    /// Left and right variants are intentionally normalized because Carbon cannot distinguish
    /// modifier sides. Returning `nil` leaves unsupported chords on Loop's existing event-tap path
    /// instead of registering a shortcut with different semantics.
    init?(keyCodes: Set<CGKeyCode>) {
        let normalizedKeyCodes: Set<CGKeyCode> = keyCodes.baseModifiers
        let ordinaryKeys: Set<CGKeyCode> = normalizedKeyCodes.filter { !$0.isModifier }

        guard ordinaryKeys.count == 1, let keyCode: CGKeyCode = ordinaryKeys.first else {
            return nil
        }

        var modifiers: UInt32 = 0
        for modifier: CGKeyCode in normalizedKeyCodes.filter(\.isModifier) {
            switch modifier {
            case .kVK_Command:
                modifiers |= UInt32(cmdKey)
            case .kVK_Option:
                modifiers |= UInt32(optionKey)
            case .kVK_Control:
                modifiers |= UInt32(controlKey)
            case .kVK_Shift:
                modifiers |= UInt32(shiftKey)
            case .kVK_Function:
                modifiers |= UInt32(kEventKeyModifierFnMask)
            default:
                return nil
            }
        }

        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyCodes = normalizedKeyCodes
    }
}

/// Connects a registered Carbon shortcut to the Loop action it should perform.
struct SystemHotKeyBinding: Hashable {
    let shortcut: SystemHotKeyShortcut
    let action: WindowAction

    /// Whether the action works without Loop's trigger key.
    ///
    /// Bypass actions must close Loop when Carbon reports their key release. Normal actions remain
    /// governed by the trigger-key lifecycle, matching the existing event-tap behavior.
    let bypassesTrigger: Bool
}

/// Produces only the subset of configured Loop keybinds that Carbon can represent faithfully.
enum SystemHotKeyBindingResolver {
    /// Resolves normal, reverse-cycle, and trigger-bypassing actions into Carbon registrations.
    ///
    /// Side-dependent trigger configurations are excluded wholesale because Carbon reports only a
    /// generic modifier bit. Registering those chords would make a left-only or right-only setting
    /// fire from either side. When multiple actions resolve to the same Carbon chord, the first
    /// configured action wins, matching the lookup behavior of Loop's existing keybind cache.
    static func resolve(
        keybinds: [WindowAction],
        triggerKey: Set<CGKeyCode>,
        sideDependentTriggerKey: Bool,
        cycleBackwardsOnShiftPressed: Bool
    ) -> [SystemHotKeyBinding] {
        guard !sideDependentTriggerKey else { return [] }

        let normalActions: [WindowAction] = keybinds.filter {
            $0.bypassTriggerKey != true && !$0.keybind.isEmpty
        }
        let bypassActions: [WindowAction] = keybinds.filter {
            $0.bypassTriggerKey == true && !$0.keybind.isEmpty
        }
        var bindings: [SystemHotKeyBinding] = []
        var registeredShortcuts: Set<SystemHotKeyShortcut> = []

        // Keep conversion and duplicate rejection identical for every binding category below.
        func append(
            action: WindowAction,
            keyCodes: Set<CGKeyCode>,
            bypassesTrigger: Bool
        ) -> Void {
            guard
                let shortcut: SystemHotKeyShortcut = .init(keyCodes: keyCodes),
                registeredShortcuts.insert(shortcut).inserted
            else {
                return
            }

            bindings.append(.init(
                shortcut: shortcut,
                action: action,
                bypassesTrigger: bypassesTrigger
            ))
        }

        for action: WindowAction in normalActions {
            append(
                action: action,
                keyCodes: triggerKey.union(action.keybind),
                bypassesTrigger: false
            )
        }

        if cycleBackwardsOnShiftPressed {
            // Reverse cycling is the normal cycle chord plus Shift, so it needs its own Carbon ID.
            for action: WindowAction in normalActions where action.direction == .cycle {
                append(
                    action: action,
                    keyCodes: triggerKey.union(action.keybind).union([.kVK_Shift]),
                    bypassesTrigger: false
                )
            }
        }

        for action: WindowAction in bypassActions {
            append(
                action: action,
                keyCodes: action.keybind,
                bypassesTrigger: true
            )
        }

        return bindings
    }
}
