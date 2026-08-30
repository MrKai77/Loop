//
//  CycleActionCoordinatorTests.swift
//  LoopTests
//
//  Created by Kai Azim on 2026-08-30.
//

@testable import Loop
import Testing

struct CycleActionCoordinatorTests {
    @Test func restartPolicyOnlyRestartsInterruptedCyclesWhenEnabled() {
        let first = WindowAction(.leftHalf)
        let second = WindowAction(.rightHalf)
        let outside = WindowAction(.maximize)
        let children = [first, second]
        let cycle = WindowAction(children)
        let prefixCycle = WindowAction(cycle: [outside], keybind: [.kVK_LeftArrow])
        let dualKeyCycle = WindowAction(
            cycle: children,
            keybind: [.kVK_LeftArrow, .kVK_RightArrow]
        )
        let unrelatedCycle = WindowAction(cycle: [outside], keybind: [.kVK_UpArrow])

        #expect(CycleActionCoordinator.shouldRestartAtBeginning(
            whenEnabled: true,
            currentAction: outside,
            currentParentAction: nil,
            keybindSequenceOriginAction: nil,
            in: cycle
        ))
        #expect(CycleActionCoordinator.shouldRestartAtBeginning(
            whenEnabled: true,
            currentAction: .init(.noSelection),
            currentParentAction: nil,
            keybindSequenceOriginAction: nil,
            in: cycle
        ))
        #expect(!CycleActionCoordinator.shouldRestartAtBeginning(
            whenEnabled: true,
            currentAction: first,
            currentParentAction: cycle,
            keybindSequenceOriginAction: nil,
            in: cycle
        ))
        #expect(!CycleActionCoordinator.shouldRestartAtBeginning(
            whenEnabled: false,
            currentAction: outside,
            currentParentAction: nil,
            keybindSequenceOriginAction: nil,
            in: cycle
        ))
        #expect(CycleActionCoordinator.shouldRestartAtBeginning(
            whenEnabled: true,
            currentAction: outside,
            currentParentAction: prefixCycle,
            keybindSequenceOriginAction: nil,
            in: dualKeyCycle
        ))
        #expect(!CycleActionCoordinator.shouldRestartAtBeginning(
            whenEnabled: true,
            currentAction: outside,
            currentParentAction: prefixCycle,
            keybindSequenceOriginAction: dualKeyCycle,
            in: dualKeyCycle
        ))
        #expect(CycleActionCoordinator.shouldRestartAtBeginning(
            whenEnabled: true,
            currentAction: outside,
            currentParentAction: prefixCycle,
            keybindSequenceOriginAction: unrelatedCycle,
            in: dualKeyCycle
        ))
    }
}
