//
//  RadialMenuViewModel.swift
//  Loop
//
//  Created by Kai Azim on 2025-08-31.
//

import Defaults
import SwiftUI

/// This class is in charge of managing the state of the radial menu, including the current action, angle, and colors.
/// By keeping the state separate, we are able to use the same `RadialMenuView` both in the app's settings, as well as in actual usage.
final class RadialMenuViewModel: ObservableObject {
    @Published private(set) var angle: Double
    @Published private(set) var currentAction: WindowAction?

    private var previousAction: WindowAction?
    private let window: Window?
    let previewMode: Bool

    init(
        startingAction: WindowAction?,
        window: Window?,
        previewMode: Bool
    ) {
        self.currentAction = startingAction
        self.previousAction = startingAction
        self.window = window
        self.previewMode = previewMode

        // Auto-set properties
        self.angle = .zero

        recomputeAngle()
    }

    var invalidWindowSelected: Bool {
        window == nil && !previewMode
    }

    var shouldFillRadialMenu: Bool {
        currentAction?.direction.shouldFillRadialMenu ?? false
    }

    var shouldHideDirectionSelector: Bool {
        currentAction?.direction.hasRadialMenuAngle != true || currentAction?.direction.isCustomizable == true
    }

    var radialMenuScale: CGFloat {
        currentAction?.direction == .maximize ? 0.85 : 1
    }

    var radialMenuImage: Image? {
        currentAction?.radialMenuImage
    }

    func setAction(to action: WindowAction) {
        previousAction = currentAction
        currentAction = action

        recomputeAngle()
    }

    func recomputeAngle() {
        if let target = currentAction?.radialMenuAngle(window: window) {
            let closestAngle: Angle = .degrees(angle).angleDifference(to: target)

            let previousActionHadAngle = previousAction?.direction.hasRadialMenuAngle ?? false
            let animate: Bool = abs(closestAngle.degrees) < 179 && previousActionHadAngle

            let defaultAnimation = AnimationConfiguration.fast.radialMenuAngle
            let noAnimation = Animation.linear(duration: 0)

            withAnimation(animate ? defaultAnimation : noAnimation) {
                angle += closestAngle.degrees
            }
        }
    }
}
