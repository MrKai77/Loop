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

    let noActionCursorDistance: CGFloat = 8
    let radialMenuSize: CGFloat = 100

    // This will determine whether Loop needs to show a warning (if it's nil)
    let frontmostWindow: Window?

    @State var previewMode = false
    @State var initialMousePosition: CGPoint = CGPoint()
    @State var timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    @State private var currentResizeDirection: WindowDirection = .noAction

    @State var angleToMouse: Angle = Angle(degrees: 0)
    @State var distanceToMouse: CGFloat = 0

    // Variables that store the radial menu's shape
    @Default(.radialMenuCornerRadius) var radialMenuCornerRadius
    @Default(.radialMenuThickness) var radialMenuThickness
    @Default(.useGradient) var useGradient

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
                                RadialMenuDirectionSelectorView(
                                    activeAngle: currentResizeDirection,
                                    size: self.radialMenuSize
                                )
                            }
                    }
                    // Mask the whole ZStack with the shape the user defines
                    .mask {
                        if radialMenuCornerRadius == radialMenuSize / 2 {
                            Circle()
                                .strokeBorder(.black, lineWidth: radialMenuThickness)
                        } else {
                            RoundedRectangle(cornerRadius: radialMenuCornerRadius, style: .continuous)
                                .strokeBorder(.black, lineWidth: radialMenuThickness)
                        }
                    }

                    if frontmostWindow == nil && previewMode == false {
                        Image("custom.macwindow.trianglebadge.exclamationmark")
                            .foregroundStyle(Color.getLoopAccent(tone: .normal))
                            .font(Font.system(size: 20, weight: .bold))
                    }
                }
                .frame(width: radialMenuSize, height: radialMenuSize)

                Spacer()
            }
            Spacer()
        }
        .shadow(radius: 10)

        // Animate window
        .scaleEffect(currentResizeDirection == .maximize ? 0.85 : 1)
        .animation(.easeInOut, value: currentResizeDirection)
        .onAppear {
            if previewMode {
                currentResizeDirection = .topHalf
            }
        }
        .onReceive(timer) { _ in
            if !previewMode {
                self.refreshCurrentAngle()
            } else {
                currentResizeDirection = currentResizeDirection.nextPreviewDirection

                if currentResizeDirection == .rightThird {
                    currentResizeDirection = .topHalf
                }
            }
        }
        .onReceive(.directionChanged) { obj in
            if let direction = obj.userInfo?["direction"] as? WindowDirection {
                self.currentResizeDirection = direction
            }
        }
    }

    private func refreshCurrentAngle() {
        let currentMouseLocation = NSEvent.mouseLocation
        let currentAngleToMouse = Angle(radians: initialMousePosition.angle(to: currentMouseLocation))
        let currentDistanceToMouse = initialMousePosition.distanceSquared(to: currentMouseLocation)

        if (currentAngleToMouse == angleToMouse) && (currentDistanceToMouse == distanceToMouse) {
            return
        }

        // Get angle & distance to mouse
        self.angleToMouse = currentAngleToMouse
        self.distanceToMouse = currentDistanceToMouse

        // If mouse over 50 points away, select half or quarter positions
        let previousResizeDirection = currentResizeDirection
        if distanceToMouse > pow(50 - radialMenuThickness, 2) {
            switch Int((angleToMouse.normalized().degrees + 22.5) / 45) {
            case 0, 8: currentResizeDirection = .rightHalf
            case 1:    currentResizeDirection = .bottomRightQuarter
            case 2:    currentResizeDirection = .bottomHalf
            case 3:    currentResizeDirection = .bottomLeftQuarter
            case 4:    currentResizeDirection = .leftHalf
            case 5:    currentResizeDirection = .topLeftQuarter
            case 6:    currentResizeDirection = .topHalf
            case 7:    currentResizeDirection = .topRightQuarter
            default:   currentResizeDirection = .noAction
            }
        } else if distanceToMouse < pow(noActionCursorDistance, 2) {
            currentResizeDirection = .noAction
        } else {
            currentResizeDirection = .maximize
        }

        // When direction changes, send haptic feedback and post a
        // notification which is used to position the preview window
        if currentResizeDirection != previousResizeDirection {
            NotificationCenter.default.post(
                name: Notification.Name.directionChanged,
                object: nil,
                userInfo: ["direction": currentResizeDirection]
            )
        }
    }
}
