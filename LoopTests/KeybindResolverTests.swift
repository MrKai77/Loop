//
//  KeybindResolverTests.swift
//  LoopTests
//
//  Created by Kai Azim on 2026-08-29.
//

import CoreGraphics
@testable import Loop
import Testing

struct KeybindResolverTests {
    private let triggerKey: Set<CGKeyCode> = [.kVK_Control]
    private let keyA: CGKeyCode = .kVK_LeftArrow
    private let keyB: CGKeyCode = .kVK_RightArrow

    @Test func overlappingChordReactivatesWithoutMatchingItsSubsetOnKeyUp() throws {
        let singleCycle = WindowAction([
            .init(.leftHalf),
            .init(.rightHalf)
        ])
        let chordCycle = WindowAction([
            .init(.topHalf),
            .init(.bottomHalf)
        ])
        let actions: [Set<CGKeyCode>: WindowAction] = [
            [keyA]: singleCycle,
            [keyA, keyB]: chordCycle
        ]

        let singleDown = resolve(
            eventType: .keyDown,
            pressedKeys: [keyA],
            actions: actions
        )
        let chordDown = resolve(
            eventType: .keyDown,
            pressedKeys: [keyA, keyB],
            actions: actions
        )
        let chordKeyUp = resolve(
            eventType: .keyUp,
            pressedKeys: [keyA],
            actions: actions
        )
        let chordRepressed = resolve(
            eventType: .keyDown,
            pressedKeys: [keyA, keyB],
            actions: actions
        )

        try expectOpen(singleDown.effect, action: singleCycle, overridesDelayAction: true)
        try expectOpen(chordDown.effect, action: chordCycle, overridesDelayAction: true)
        #expect(chordKeyUp.effect == .none)
        #expect(chordKeyUp.handling == .forward)
        try expectOpen(chordRepressed.effect, action: chordCycle, overridesDelayAction: true)
    }

    @Test func cycleAutorepeatIsSuppressed() {
        let cycle = WindowAction([
            .init(.leftHalf),
            .init(.rightHalf)
        ])
        let decision = resolve(
            eventType: .keyDown,
            isRepeat: true,
            pressedKeys: [keyA],
            actions: [[keyA]: cycle]
        )

        #expect(decision.effect == .none)
        #expect(decision.handling == .consumeIfLoopOpenOtherwiseOpening)
    }

    @Test func nonRepeatableActionAutorepeatIsSuppressed() {
        let action = WindowAction(.leftHalf)
        let decision = resolve(
            eventType: .keyDown,
            isRepeat: true,
            pressedKeys: [keyA],
            actions: [[keyA]: action]
        )

        #expect(decision.effect == .none)
        #expect(decision.handling == .consumeIfLoopOpenOtherwiseOpening)
    }

    @Test func repeatableActionActivatesOnAutorepeat() throws {
        let action = WindowAction(.larger)
        let decision = resolve(
            eventType: .keyDown,
            isRepeat: true,
            pressedKeys: [keyA],
            actions: [[keyA]: action]
        )

        try expectOpen(decision.effect, action: action, overridesDelayAction: true)
        #expect(decision.handling == .consumeIfLoopOpenOtherwiseOpening)
    }

    @Test func bypassActionActivatesWithoutTheTriggerKey() throws {
        let action = WindowAction(.rightHalf)
        let decision = resolve(
            eventType: .keyDown,
            pressedKeys: [keyA],
            modifierKeys: [],
            isLoopOpen: false,
            bypassedActions: [[keyA]: action]
        )

        try expectOpen(decision.effect, action: action, overridesDelayAction: true)
        #expect(decision.handling == .consumeIfLoopOpenOtherwiseOpening)
    }

    @Test func sideIndependentTriggerAcceptsTheOppositeModifierSide() throws {
        let action = WindowAction(.leftHalf)
        let decision = resolve(
            eventType: .keyDown,
            pressedKeys: [keyA],
            modifierKeys: [.kVK_RightControl],
            isSideDependent: false,
            actions: [[keyA]: action]
        )

        try expectOpen(decision.effect, action: action, overridesDelayAction: true)
        #expect(decision.handling == .consumeIfLoopOpenOtherwiseOpening)
    }

    @Test func sideDependentTriggerRejectsTheOppositeModifierSide() {
        let action = WindowAction(.leftHalf)
        let decision = resolve(
            eventType: .keyDown,
            pressedKeys: [keyA],
            modifierKeys: [.kVK_RightControl],
            isSideDependent: true,
            actions: [[keyA]: action]
        )

        #expect(decision.effect == .close(force: false, notifyDoubleClickKeyUp: false))
        #expect(decision.handling == .forward)
    }

    @Test func escapeForceClosesAnOpenSession() {
        let decision = resolve(
            eventType: .keyDown,
            pressedKeys: [.kVK_Escape]
        )

        #expect(decision.effect == .close(force: true, notifyDoubleClickKeyUp: false))
        #expect(decision.handling == .consume)
    }

    @Test func triggerReleaseGracefullyClosesAnOpenSession() {
        let decision = resolve(
            eventType: .flagsChanged,
            pressedKeys: [],
            modifierKeys: []
        )

        #expect(decision.effect == .close(force: false, notifyDoubleClickKeyUp: false))
        #expect(decision.handling == .forward)
    }

    @Test func triggerAloneOpensWithoutASelectedAction() throws {
        let decision = resolve(
            eventType: .flagsChanged,
            pressedKeys: [],
            isLoopOpen: false
        )

        let opened = try #require(openEffect(decision.effect))
        #expect(opened.action.direction == .noSelection)
        #expect(opened.overridesDelayAction)
        #expect(decision.handling == .opening)
    }

    @Test func emptyUnmatchedInputNotifiesTheDoubleClickTimer() {
        let decision = resolve(
            eventType: .flagsChanged,
            pressedKeys: [],
            modifierKeys: [],
            isLoopOpen: false
        )

        #expect(decision.effect == .close(force: false, notifyDoubleClickKeyUp: true))
        #expect(decision.handling == .forward)
    }

    private func resolve(
        eventType: KeybindResolver.EventType,
        isRepeat: Bool = false,
        pressedKeys: Set<CGKeyCode>,
        modifierKeys: Set<CGKeyCode>? = nil,
        isSideDependent: Bool = false,
        isLoopOpen: Bool = true,
        actions: [Set<CGKeyCode>: WindowAction] = [:],
        bypassedActions: [Set<CGKeyCode>: WindowAction] = [:]
    ) -> KeybindResolver.Decision {
        KeybindResolver.resolve(
            .init(
                eventType: eventType,
                isRepeat: isRepeat,
                pressedKeys: pressedKeys,
                modifierKeys: modifierKeys ?? triggerKey,
                trigger: .init(
                    keys: triggerKey,
                    isSideDependent: isSideDependent
                ),
                isLoopOpen: isLoopOpen,
                actionsByKeybind: actions,
                bypassedActionsByKeybind: bypassedActions
            )
        )
    }

    private func expectOpen(
        _ effect: KeybindResolver.Effect,
        action expectedAction: WindowAction,
        overridesDelayAction: Bool
    ) throws {
        let open = try #require(openEffect(effect))
        #expect(open.action.id == expectedAction.id)
        #expect(open.overridesDelayAction == overridesDelayAction)
    }

    private func openEffect(
        _ effect: KeybindResolver.Effect
    ) -> (action: WindowAction, overridesDelayAction: Bool)? {
        guard case let .open(action, overridesDelayAction) = effect else {
            return nil
        }
        return (action, overridesDelayAction)
    }
}
