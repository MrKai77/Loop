//
//  RadialMenuView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Combine
import Defaults

struct RadialMenuView: View {

    let radialMenuSize: CGFloat = 100

    @State var currentAction: WindowAction
    @State var previousAction: WindowAction?

    private let window: Window?
    private let previewMode: Bool

    @State var timer: Publishers.Autoconnect<Timer.TimerPublisher>

    // Variables that store the radial menu's shape
    @Default(.radialMenuCornerRadius) var radialMenuCornerRadius
    @Default(.radialMenuThickness) var radialMenuThickness
    @Default(.useGradient) var useGradient
    @Default(.animationConfiguration) var animationConfiguration

    init(previewMode: Bool = false, window: Window?, startingAction: WindowAction = .init(.noAction)) {
        self.window = window
        self.previewMode = previewMode
        self._currentAction = State(initialValue: .init(startingAction.direction))

        if previewMode {
            self._timer = State(initialValue: Timer.publish(every: 1, on: .main, in: .common).autoconnect())
        } else {
            self._timer = State(initialValue: Timer.publish(every: -1, on: .main, in: .common).autoconnect())
        }
    }

    @State var angle: Double = .zero

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

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
                                            Color.getLoopAccent(tone: .normal),
                                            Color.getLoopAccent(tone: useGradient ? .darker : .normal)
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
                                            if self.currentAction.direction.shouldFillRadialMenu {
                                                Color.white
                                            }

                                            ZStack {
                                                if radialMenuCornerRadius >= radialMenuSize / 2 - 2 {
                                                    DirectionSelectorCircleSegment(
                                                        angle: self.angle,
                                                        radialMenuSize: self.radialMenuSize
                                                    )
                                                } else {
                                                    DirectionSelectorSquareSegment(
                                                        angle: self.angle,
                                                        radialMenuCornerRadius: self.radialMenuCornerRadius,
                                                        radialMenuThickness: self.radialMenuThickness
                                                    )
                                                }
                                            }
                                            .compositingGroup()
                                            .opacity(
                                                !self.currentAction.direction.hasRadialMenuAngle ||
                                                self.currentAction.direction == .custom ?
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
                                .padding(self.radialMenuThickness)
                        } else {
                            RoundedRectangle(cornerRadius: radialMenuCornerRadius, style: .continuous)
                                .stroke(.quinary, lineWidth: 2)

                            RoundedRectangle(cornerRadius: radialMenuCornerRadius - self.radialMenuThickness, style: .continuous)
                                .stroke(.quinary, lineWidth: 2)
                                .padding(self.radialMenuThickness)
                        }
                    }
                    // Mask the whole ZStack with the shape the user defines
                    .mask {
                        if radialMenuCornerRadius >= radialMenuSize / 2 - 2 {
                            Circle()
                                .strokeBorder(.black, lineWidth: radialMenuThickness)
                        } else {
                            RoundedRectangle(cornerRadius: radialMenuCornerRadius, style: .continuous)
                                .strokeBorder(.black, lineWidth: radialMenuThickness)
                        }
                    }

                    Group {
                        if window == nil && previewMode == false {
                            Image("custom.macwindow.trianglebadge.exclamationmark")
                        } else if let image = self.currentAction.direction.radialMenuImage {
                            image
                        }
                    }
                    .foregroundStyle(Color.getLoopAccent(tone: .normal))
                    .font(Font.system(size: 20, weight: .bold))
                }
                .frame(width: radialMenuSize, height: radialMenuSize)

                Spacer()
            }
            Spacer()
        }
        .shadow(radius: 10)

        // Animate window
        .scaleEffect(currentAction.direction == .maximize ? 0.85 : 1)
        .animation(animationConfiguration.radialMenuSize, value: currentAction)
        .onAppear {
            if previewMode {
                currentAction.direction = currentAction.direction.nextPreviewDirection
            }
        }
        .onReceive(timer) { _ in
            if previewMode {
                previousAction = currentAction
                currentAction.direction = currentAction.direction.nextPreviewDirection
            }
        }
        .onReceive(.updateUIDirection) { obj in
            if !self.previewMode, let action = obj.userInfo?["action"] as? WindowAction {
                self.previousAction = self.currentAction
                self.currentAction = .init(action.direction)

                print("New radial menu window action received: \(action.direction)")
            }
        }
        .onChange(of: self.currentAction) { _ in
            if let target = self.currentAction.radialMenuAngle(window: window) {
                let closestAngle: Angle = .degrees(self.angle).angleDifference(to: target)

                let previousActionHadAngle = self.previousAction?.direction.hasRadialMenuAngle ?? false
                let animate: Bool = abs(closestAngle.degrees) < 179 && previousActionHadAngle

                let defaultAnimation = AnimationConfiguration.fast.radialMenuAngle
                let noAnimation = Animation.linear(duration: 0)

                withAnimation(animate ? defaultAnimation : noAnimation) {
                    self.angle += closestAngle.degrees
                }
            }
        }
    }
}
