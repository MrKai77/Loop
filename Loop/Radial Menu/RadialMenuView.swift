//
//  RadialMenuView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import Combine
import Defaults
import Luminare
import SwiftUI

struct RadialMenuView: View {
    @ObservedObject var luminareModel: LuminareWindowModel = .shared

    let radialMenuSize: CGFloat = 100

    @State var currentAction: WindowAction
    @State var previousAction: WindowAction?

    private let window: Window?
    private let previewMode: Bool

    // Variables that store the radial menu's shape
    @Default(.radialMenuCornerRadius) var radialMenuCornerRadius
    @Default(.radialMenuThickness) var radialMenuThickness
    @Default(.animationConfiguration) var animationConfiguration

    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor
    @Default(.useGradient) var useGradient
    @Default(.gradientColor) var gradientColor

    init(previewMode: Bool = false, window: Window? = nil, startingAction: WindowAction = .init(.noAction)) {
        self.window = window
        self.previewMode = previewMode
        self._currentAction = State(initialValue: startingAction)
    }

    @State var angle: Double = .zero

    @State var primaryColor: Color = .getLoopAccent(tone: .normal)
    @State var secondaryColor: Color = .getLoopAccent(tone: Defaults[.useGradient] ? .darker : .normal)
    @State var isActive: Bool = true

    var body: some View {
        ZStack {
            ZStack {
                // NSVisualEffect on background
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

                // This rectangle with a gradient is masked with the current direction radial menu view
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(
                                colors: [
                                    !previewMode || isActive ? primaryColor : .systemGray,
                                    !previewMode || isActive ? secondaryColor : .systemGray
                                ]
                            ),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .mask {
                        Color.clear
                            .overlay {
                                ZStack {
                                    if currentAction.direction.shouldFillRadialMenu {
                                        Color.white
                                    }

                                    ZStack {
                                        if radialMenuCornerRadius >= radialMenuSize / 2 - 2 {
                                            DirectionSelectorCircleSegment(
                                                angle: angle,
                                                radialMenuSize: radialMenuSize
                                            )
                                        } else {
                                            DirectionSelectorSquareSegment(
                                                angle: angle,
                                                radialMenuCornerRadius: radialMenuCornerRadius,
                                                radialMenuThickness: radialMenuThickness
                                            )
                                        }
                                    }
                                    .compositingGroup()
                                    .opacity(
                                        !currentAction.direction.hasRadialMenuAngle ||
                                            currentAction.direction == .custom ?
                                            0 : 1
                                    )
                                }
                            }
                    }

                if radialMenuCornerRadius >= radialMenuSize / 2 - 2 {
                    Circle()
                        .stroke(.quinary, lineWidth: 2)

                    Circle()
                        .stroke(.quinary, lineWidth: 2)
                        .padding(radialMenuThickness)
                } else {
                    RoundedRectangle(cornerRadius: radialMenuCornerRadius)
                        .stroke(.quinary, lineWidth: 2)

                    RoundedRectangle(cornerRadius: radialMenuCornerRadius - radialMenuThickness)
                        .stroke(.quinary, lineWidth: 2)
                        .padding(radialMenuThickness)
                }
            }
            // Mask the whole ZStack with the shape the user defines
            .mask {
                if radialMenuCornerRadius >= radialMenuSize / 2 - 2 {
                    Circle()
                        .strokeBorder(.black, lineWidth: radialMenuThickness)
                } else {
                    RoundedRectangle(cornerRadius: radialMenuCornerRadius)
                        .strokeBorder(.black, lineWidth: radialMenuThickness)
                }
            }

            Group {
                if window == nil, previewMode == false {
                    Image(systemName: "exclamationmark.triangle")
                } else if let image = currentAction.radialMenuImage {
                    image
                }
            }
            .foregroundStyle(Color.getLoopAccent(tone: .normal))
            .font(Font.system(size: 20, weight: .bold))
        }
        .frame(width: radialMenuSize, height: radialMenuSize)
        .shadow(radius: 10)
        .padding(20)
        .fixedSize()
        // Animate window
        .scaleEffect(currentAction.direction == .maximize ? 0.85 : 1)
        .animation(animationConfiguration.radialMenuSize, value: currentAction)
        .onAppear {
            recomputeAngle()
        }
        .onChange(of: luminareModel.previewedAction) { _ in
            if previewMode {
                guard isActive else { return }
                previousAction = currentAction
                currentAction.direction = luminareModel.previewedAction.direction
            }
        }
        .onReceive(.updateUIDirection) { obj in
            if !previewMode, let action = obj.userInfo?["action"] as? WindowAction {
                previousAction = currentAction
                currentAction = .init(action.direction)

                print("New radial menu window action received: \(action.direction)")
            }
        }
        .onChange(of: currentAction) { _ in
            recomputeAngle()
        }
        .onChange(of: [customAccentColor, gradientColor]) { _ in
            recomputeColors()
        }
        .onChange(of: [useSystemAccentColor, useGradient]) { _ in
            recomputeColors()
        }
        .onReceive(.activeStateChanged) { notif in
            if let active = notif.object as? Bool {
                isActive = active
            }
        }
    }

    func recomputeColors() {
        withAnimation(LuminareConstants.animation) {
            primaryColor = Color.getLoopAccent(tone: .normal)
            secondaryColor = Color.getLoopAccent(tone: useGradient ? .darker : .normal)
        }
    }

    func recomputeAngle() {
        if let target = currentAction.radialMenuAngle(window: window) {
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
