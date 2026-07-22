import Carbon.HIToolbox
import XCTest

@testable import Loop

/// Documents the exact boundary between Loop's flexible key chords and Carbon-compatible hotkeys.
final class SystemHotKeyBindingTests: XCTestCase {
    func testResolvesNormalAndBypassShortcuts() throws -> Void {
        let normal: WindowAction = .init(.leftHalf, keybind: [.kVK_LeftArrow])
        let bypass: WindowAction = .init(
            .nextScreen,
            keybind: [.kVK_Command, .kVK_Control, .kVK_RightArrow],
            bypassTriggerKey: true
        )

        let bindings: [SystemHotKeyBinding] = SystemHotKeyBindingResolver.resolve(
            keybinds: [normal, bypass],
            triggerKey: [.kVK_Command, .kVK_Option],
            sideDependentTriggerKey: false,
            cycleBackwardsOnShiftPressed: false
        )

        XCTAssertEqual(bindings.count, 2)
        XCTAssertEqual(bindings[0].action, normal)
        XCTAssertEqual(bindings[0].shortcut.keyCodes, [
            .kVK_Command, .kVK_Option, .kVK_LeftArrow
        ])
        XCTAssertFalse(bindings[0].bypassesTrigger)
        XCTAssertEqual(bindings[1].action, bypass)
        XCTAssertEqual(bindings[1].shortcut.keyCodes, bypass.keybind)
        XCTAssertTrue(bindings[1].bypassesTrigger)
    }

    func testAddsReverseCycleShiftVariant() -> Void {
        let action: WindowAction = .init(
            cycle: [.init(.leftHalf), .init(.leftThird)],
            keybind: [.kVK_LeftArrow]
        )

        let bindings: [SystemHotKeyBinding] = SystemHotKeyBindingResolver.resolve(
            keybinds: [action],
            triggerKey: [.kVK_Command, .kVK_Option],
            sideDependentTriggerKey: false,
            cycleBackwardsOnShiftPressed: true
        )

        XCTAssertEqual(bindings.map(\.shortcut.keyCodes), [
            [.kVK_Command, .kVK_Option, .kVK_LeftArrow],
            [.kVK_Command, .kVK_Option, .kVK_Shift, .kVK_LeftArrow]
        ])
    }

    func testMapsCarbonModifiersAndNormalizesSides() throws -> Void {
        let shortcut: SystemHotKeyShortcut = try XCTUnwrap(.init(keyCodes: [
            .kVK_RightCommand,
            .kVK_RightOption,
            .kVK_RightControl,
            .kVK_RightShift,
            .kVK_Function,
            .kVK_Space
        ]))

        XCTAssertEqual(shortcut.keyCode, .kVK_Space)
        XCTAssertEqual(
            shortcut.modifiers,
            UInt32(cmdKey | optionKey | controlKey | shiftKey)
                | UInt32(kEventKeyModifierFnMask)
        )
        XCTAssertEqual(shortcut.keyCodes, [
            .kVK_Command,
            .kVK_Option,
            .kVK_Control,
            .kVK_Shift,
            .kVK_Function,
            .kVK_Space
        ])
    }

    func testRejectsUnsupportedShapesAndSideDependentTriggers() -> Void {
        XCTAssertNil(SystemHotKeyShortcut(keyCodes: [
            .kVK_Command, .kVK_LeftArrow, .kVK_RightArrow
        ]))
        XCTAssertNil(SystemHotKeyShortcut(keyCodes: [
            .kVK_CapsLock, .kVK_Space
        ]))

        let bindings: [SystemHotKeyBinding] = SystemHotKeyBindingResolver.resolve(
            keybinds: [.init(.leftHalf, keybind: [.kVK_LeftArrow])],
            triggerKey: [.kVK_RightCommand],
            sideDependentTriggerKey: true,
            cycleBackwardsOnShiftPressed: false
        )
        XCTAssertTrue(bindings.isEmpty)
    }

    func testKeepsFirstDuplicateBinding() -> Void {
        let first: WindowAction = .init(.leftHalf, keybind: [.kVK_LeftArrow])
        let second: WindowAction = .init(.leftThird, keybind: [.kVK_LeftArrow])

        let bindings: [SystemHotKeyBinding] = SystemHotKeyBindingResolver.resolve(
            keybinds: [first, second],
            triggerKey: [.kVK_Command, .kVK_Option],
            sideDependentTriggerKey: false,
            cycleBackwardsOnShiftPressed: false
        )

        XCTAssertEqual(bindings.map(\.action), [first])
    }
}
