//
//  CycleBackwardsView.swift
//  Loop
//
//  Created by Guillaume Clédat on 17/05/2025.
//

import Foundation
import Luminare
import SwiftUI

struct CycleBackwardsView: View {
    var triggerKey: Set<CGKeyCode>

    @Binding var isOn: Bool

    var isShiftUsedByTriggerKey: Bool {
        triggerKey.contains(.kVK_Shift)
    }

    var body: some View {
        LuminareToggle("Cycle backward with Shift", info: cycleBackwardsInfoView, isOn: $isOn)
            .onChange(of: isShiftUsedByTriggerKey) { newValue in
                if newValue {
                    isOn = false
                }
            }
    }

    private var cycleBackwardsInfoView: LuminareInfoView? {
        guard isShiftUsedByTriggerKey else { return nil }
        return LuminareInfoView(
            "Cycling actions backward will only work\nif Shift isn't in your trigger key",
            .blue
        )
    }
}
