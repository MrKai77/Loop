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
    @Published private(set) var currentAction: WindowAction

    /// If a cycling action is chosen, this will represent the enclosing cycle action
    @Published private(set) var parentAction: WindowAction?

    private var previousAction: WindowAction?
    private var window: Window?
    let previewMode: Bool

    init(
        startingAction: WindowAction,
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

    private var effectiveWindowAction: WindowAction {
        parentAction ?? currentAction
    }

    private var radialMenuActions: [RadialMenuAction] {
        RadialMenuAction.userConfiguredActions
    }

    private var directionalRadialMenuActions: [RadialMenuAction] {
        radialMenuActions.dropLast()
    }

    private var centerRadialMenuAction: RadialMenuAction? {
        radialMenuActions.last
    }

    var shouldFillRadialMenu: Bool {
        // If the user has the center action selected, then fill the radial menu
        if effectiveWindowAction.id == centerRadialMenuAction?.associatedActionId {
            return true
        }

        guard !directionalRadialMenuActions.contains(where: { $0.associatedActionId == effectiveWindowAction.id }) else {
            return false
        }

        // Otherwise, default to the action's settings
        return effectiveWindowAction.direction.shouldFillRadialMenu
    }

    var shouldHideDirectionSelector: Bool {
        // If the current action is a user-set radial menu action, always show the direction selector
        if radialMenuActions.contains(where: { $0.associatedActionId == effectiveWindowAction.id }) {
            return false
        }

        // Otherwise, default to the action's settings
        return currentAction.direction.hasRadialMenuAngle != true || currentAction.direction.isCustomizable == true
    }

    var radialMenuImage: Image? {
        if window == nil, !previewMode {
            return Image(systemName: "exclamationmark.triangle")
        } else if let image = currentAction.image {
            let image = image.withSymbolConfiguration(.init(pointSize: 20, weight: .bold)) ?? image
            return Image(nsImage: image)
        } else {
            return nil
        }
    }

    func setWindow(to newWindow: Window) {
        window = newWindow
    }

    func setAction(to action: WindowAction, parent: WindowAction? = nil) {
        previousAction = currentAction
        currentAction = action
        parentAction = parent

        recomputeAngle()
    }

    func recomputeAngle() {
        guard let targetAngle = calculateTargetAngle() else { return }

        let closestAngle = Angle.degrees(angle).angleDifference(to: targetAngle)
        let shouldAnimate = shouldAnimateTransition(closestAngle: closestAngle)

        withAnimation(shouldAnimate ? AnimationConfiguration.radialMenuAngle : .linear(duration: 0)) {
            angle += closestAngle.degrees
        }
    }

    private func calculateTargetAngle() -> Angle? {
        // Check directional radial menu actions first
        if let index = directionalRadialMenuActions.firstIndex(where: { $0.associatedActionId == effectiveWindowAction.id }) {
            let actionAngleSpan = 360.0 / CGFloat(directionalRadialMenuActions.count)
            return Angle(degrees: CGFloat(index) * actionAngleSpan - 90)
        }

        // Otherwise, default to the current action's radial menu angle
        return currentAction.radialMenuAngle(window: window)
    }

    private func shouldAnimateTransition(closestAngle: Angle) -> Bool {
        guard abs(closestAngle.degrees) < 179 else { return false }

        if let previousAction {
            return directionalRadialMenuActions.contains(where: { $0.associatedActionId == previousAction.id }) || previousAction.direction.hasRadialMenuAngle
        }

        return false
    }
}
