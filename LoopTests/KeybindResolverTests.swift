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

        try expectAction(
            singleDown,
            action: singleCycle,
            source: .trigger,
            category: .cycle,
            activation: .activate
        )
        try expectAction(
            chordDown,
            action: chordCycle,
            source: .trigger,
            category: .cycle,
            activation: .activate
        )
        #expect(chordKeyUp.match == .none)
        #expect(chordKeyUp.effect == .none)
        #expect(chordKeyUp.handling == .forward)
        try expectAction(
            chordRepressed,
            action: chordCycle,
            source: .trigger,
            category: .cycle,
            activation: .activate
        )
    }

    @Test func cycleAutorepeatIsSuppressed() throws {
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

        try expectAction(
            decision,
            action: cycle,
            source: .trigger,
            category: .cycle,
            activation: .suppressAutorepeat
        )
        #expect(decision.effect == .none)
        #expect(decision.handling == .consumeIfLoopOpenOtherwiseOpening)
    }

    @Test func nonRepeatableActionAutorepeatIsSuppressed() throws {
        let action = WindowAction(.leftHalf)
        let decision = resolve(
            eventType: .keyDown,
            isRepeat: true,
            pressedKeys: [keyA],
            actions: [[keyA]: action]
        )

        try expectAction(
            decision,
            action: action,
            source: .trigger,
            category: .nonRepeatable,
            activation: .suppressAutorepeat
        )
        #expect(decision.effect == .none)
    }

    @Test func repeatableActionActivatesOnAutorepeat() throws {
        let action = WindowAction(.larger)
        let decision = resolve(
            eventType: .keyDown,
            isRepeat: true,
            pressedKeys: [keyA],
            actions: [[keyA]: action]
        )

        try expectAction(
            decision,
            action: action,
            source: .trigger,
            category: .repeatableNonCycle,
            activation: .activate
        )
        try expectOpen(decision.effect, action: action, overridesDelayAction: true)
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

        try expectAction(
            decision,
            action: action,
            source: .bypassTrigger,
            category: .nonRepeatable,
            activation: .activate
        )
        try expectOpen(decision.effect, action: action, overridesDelayAction: true)
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

        try expectAction(
            decision,
            action: action,
            source: .trigger,
            category: .nonRepeatable,
            activation: .activate
        )
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

        #expect(decision.match == .none)
        #expect(decision.effect == .close(force: false, notifyDoubleClickKeyUp: false))
        #expect(decision.handling == .forward)
    }

    @Test func escapeForceClosesAnOpenSession() {
        let decision = resolve(
            eventType: .keyDown,
            pressedKeys: [.kVK_Escape]
        )

        #expect(decision.match == .escape)
        #expect(decision.effect == .close(force: true, notifyDoubleClickKeyUp: false))
        #expect(decision.handling == .consume)
    }

    @Test func triggerReleaseGracefullyClosesAnOpenSession() {
        let decision = resolve(
            eventType: .flagsChanged,
            pressedKeys: [],
            modifierKeys: []
        )

        #expect(decision.match == .triggerReleasedWhileOpen)
        #expect(decision.effect == .close(force: false, notifyDoubleClickKeyUp: false))
        #expect(decision.handling == .forward)
    }

    @Test func triggerAloneOpensWithoutASelectedAction() throws {
        let decision = resolve(
            eventType: .flagsChanged,
            pressedKeys: [],
            isLoopOpen: false
        )

        #expect(decision.match == .triggerOnly)
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

        #expect(decision.match == .none)
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

    private func expectAction(
        _ decision: KeybindResolver.Decision,
        action expectedAction: WindowAction,
        source expectedSource: KeybindResolver.ActionSource,
        category expectedCategory: KeybindResolver.ActionCategory,
        activation expectedActivation: KeybindResolver.Activation
    ) throws {
        let match = try #require(actionMatch(decision.match))
        #expect(match.action.id == expectedAction.id)
        #expect(match.source == expectedSource)
        #expect(match.category == expectedCategory)
        #expect(match.activation == expectedActivation)
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

    private func actionMatch(
        _ match: KeybindResolver.Match
    ) -> (
        action: WindowAction,
        source: KeybindResolver.ActionSource,
        category: KeybindResolver.ActionCategory,
        activation: KeybindResolver.Activation
    )? {
        guard case let .action(action, source, category, activation) = match else {
            return nil
        }
        return (action, source, category, activation)
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
