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
        #expect(isNoMatch(chordKeyUp.match))
        #expect(hasNoEffect(chordKeyUp.effect))
        #expect(isForward(chordKeyUp.handling))
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
        #expect(hasNoEffect(decision.effect))
        #expect(isConsumeIfOpen(decision.handling))
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
        #expect(hasNoEffect(decision.effect))
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

        #expect(isNoMatch(decision.match))
        #expect(isGracefulClose(decision.effect, notifiesDoubleClick: false))
        #expect(isForward(decision.handling))
    }

    @Test func escapeForceClosesAnOpenSession() {
        let decision = resolve(
            eventType: .keyDown,
            pressedKeys: [.kVK_Escape]
        )

        #expect(isEscape(decision.match))
        #expect(isForcedClose(decision.effect))
        #expect(isConsume(decision.handling))
    }

    @Test func triggerReleaseGracefullyClosesAnOpenSession() {
        let decision = resolve(
            eventType: .flagsChanged,
            pressedKeys: [],
            modifierKeys: []
        )

        #expect(isTriggerRelease(decision.match))
        #expect(isGracefulClose(decision.effect, notifiesDoubleClick: false))
        #expect(isForward(decision.handling))
    }

    @Test func triggerAloneOpensWithoutASelectedAction() throws {
        let decision = resolve(
            eventType: .flagsChanged,
            pressedKeys: [],
            isLoopOpen: false
        )

        #expect(isTriggerOnly(decision.match))
        let opened = try #require(openEffect(decision.effect))
        #expect(opened.action.direction == .noSelection)
        #expect(opened.overridesDelayAction)
        #expect(isOpening(decision.handling))
    }

    @Test func emptyUnmatchedInputNotifiesTheDoubleClickTimer() {
        let decision = resolve(
            eventType: .flagsChanged,
            pressedKeys: [],
            modifierKeys: [],
            isLoopOpen: false
        )

        #expect(isNoMatch(decision.match))
        #expect(isGracefulClose(decision.effect, notifiesDoubleClick: true))
        #expect(isForward(decision.handling))
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

    private func isNoMatch(_ match: KeybindResolver.Match) -> Bool {
        if case .none = match { true } else { false }
    }

    private func isEscape(_ match: KeybindResolver.Match) -> Bool {
        if case .escape = match { true } else { false }
    }

    private func isTriggerRelease(_ match: KeybindResolver.Match) -> Bool {
        if case .triggerReleasedWhileOpen = match { true } else { false }
    }

    private func isTriggerOnly(_ match: KeybindResolver.Match) -> Bool {
        if case .triggerOnly = match { true } else { false }
    }

    private func hasNoEffect(_ effect: KeybindResolver.Effect) -> Bool {
        if case .none = effect { true } else { false }
    }

    private func isForcedClose(_ effect: KeybindResolver.Effect) -> Bool {
        if case let .close(force, notifyDoubleClickKeyUp) = effect {
            force && !notifyDoubleClickKeyUp
        } else {
            false
        }
    }

    private func isGracefulClose(
        _ effect: KeybindResolver.Effect,
        notifiesDoubleClick: Bool
    ) -> Bool {
        if case let .close(force, notifyDoubleClickKeyUp) = effect {
            !force && notifyDoubleClickKeyUp == notifiesDoubleClick
        } else {
            false
        }
    }

    private func isForward(_ handling: KeybindResolver.HandlingIntent) -> Bool {
        if case .forward = handling { true } else { false }
    }

    private func isConsume(_ handling: KeybindResolver.HandlingIntent) -> Bool {
        if case .consume = handling { true } else { false }
    }

    private func isOpening(_ handling: KeybindResolver.HandlingIntent) -> Bool {
        if case .opening = handling { true } else { false }
    }

    private func isConsumeIfOpen(_ handling: KeybindResolver.HandlingIntent) -> Bool {
        if case .consumeIfLoopOpenOtherwiseOpening = handling { true } else { false }
    }
}
