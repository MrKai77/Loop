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
    let frontmostWindow: AXUIElement?

    @State var previewMode = false
    @State var initialMousePosition: CGPoint = CGPoint()
    @State var timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    @State private var currentResizeDirection: WindowDirection = .noAction

    @State var angleToMouse: Angle = Angle(degrees: 0)
    @State var distanceToMouse: CGFloat = 0

    // Variables that store the radial menu's shape
    @Default(.radialMenuCornerRadius) var radialMenuCornerRadius
    @Default(.radialMenuThickness) var radialMenuThickness

    // Color variables
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor
    @Default(.useGradient) var useGradient
    @Default(.gradientColor) var gradientColor

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                ZStack {
                    ZStack {
                        // NSVisualEffect on background
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

                        // Used as the background when resize direction is .maximize
                        LinearGradient(
                            gradient: Gradient(
                                colors: [
                                    useSystemAccentColor ?
                                        Color.accentColor :
                                        customAccentColor,
                                    useGradient ?
                                        useSystemAccentColor ?
                                            Color(nsColor: NSColor.controlAccentColor.blended(withFraction: 0.5, of: .black)!) :
                                            gradientColor :
                                        useSystemAccentColor ?
                                            Color.accentColor :
                                            customAccentColor
                                    ]
                            ),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .opacity(currentResizeDirection == .maximize ? 1 : 0)

                        // This rectangle with a gradient is masked with the current direction radial menu view
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(
                                        colors: [
                                            useSystemAccentColor ?
                                                Color.accentColor :
                                                customAccentColor,
                                            useGradient ?
                                                useSystemAccentColor ?
                                                    Color(nsColor: NSColor.controlAccentColor.blended(withFraction: 0.5, of: .black)!) :
                                                    gradientColor :
                                                useSystemAccentColor ?
                                                    Color.accentColor :
                                                    customAccentColor
                                            ]
                                    ),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .mask {
                                RadialMenu(activeAngle: currentResizeDirection)
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
                            .foregroundStyle(useSystemAccentColor ? Color.accentColor : customAccentColor)
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
                let currentAngleToMouse = Angle(
                    radians: initialMousePosition.angle(to: CGPoint(x: NSEvent.mouseLocation.x,
                                                                    y: NSEvent.mouseLocation.y))
                )

                let currentDistanceToMouse = initialMousePosition.distanceSquared(
                    to: CGPoint(
                        x: NSEvent.mouseLocation.x,
                        y: NSEvent.mouseLocation.y
                    )
                )

                if (currentAngleToMouse == angleToMouse) && (currentDistanceToMouse == distanceToMouse) {
                    return
                }

                // Get angle & distance to mouse
                self.angleToMouse = currentAngleToMouse
                self.distanceToMouse = currentDistanceToMouse

                // If mouse over 50 points away, select half or quarter positions
                if distanceToMouse > pow(50 - radialMenuThickness, 2) {
                    switch Int((angleToMouse.normalized().degrees + 45 / 2) / 45) {
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
            } else {
                currentResizeDirection = currentResizeDirection.nextWindowDirection

                if currentResizeDirection == .rightThird {
                    currentResizeDirection = .topHalf
                }
            }
        }
        // When direction changes, send haptic feedback and post a
        // notification which is used to position the preview window
        .onChange(of: currentResizeDirection) { _ in
            if !previewMode {
                NotificationCenter.default.post(
                    name: Notification.Name.directionChanged,
                    object: nil,
                    userInfo: ["Direction": currentResizeDirection]
                )
            }
        }

        .onReceive(.directionChanged) { obj in
            if let direction = obj.userInfo?["Direction"] as? WindowDirection {
                self.currentResizeDirection = direction
            }
        }
    }
}

struct RadialMenu: View {
    @Default(.radialMenuCornerRadius) var radialMenuCornerRadius

    var activeAngle: WindowDirection

    var body: some View {
            if radialMenuCornerRadius < 40 {
                // This is used when the user configures the radial menu to be a square
                Color.clear
                    .overlay {
                        HStack(spacing: 0) {
                            VStack(spacing: 0) {
                                AngleSelectorRectangle(.topLeftQuarter, activeAngle)
                                AngleSelectorRectangle(.leftHalf, activeAngle)
                                AngleSelectorRectangle(.bottomLeftQuarter, activeAngle)
                            }
                            VStack(spacing: 0) {
                                AngleSelectorRectangle(.topHalf, activeAngle)
                                Spacer().frame(width: 100/3, height: 100/3)
                                AngleSelectorRectangle(.bottomHalf, activeAngle)
                            }
                            VStack(spacing: 0) {
                                AngleSelectorRectangle(.topRightQuarter, activeAngle)
                                AngleSelectorRectangle(.rightHalf, activeAngle)
                                AngleSelectorRectangle(.bottomRightQuarter, activeAngle)
                            }
                        }
                    }

            } else {
                // This is used when the user configures the radial menu to be a circle
                Color.clear
                    .overlay {
                        AngleSelectorCircleSegment(-22.5, .rightHalf, activeAngle)
                        AngleSelectorCircleSegment(22.5, .bottomRightQuarter, activeAngle)
                        AngleSelectorCircleSegment(67.5, .bottomHalf, activeAngle)
                        AngleSelectorCircleSegment(112.5, .bottomLeftQuarter, activeAngle)
                        AngleSelectorCircleSegment(157.5, .leftHalf, activeAngle)
                        AngleSelectorCircleSegment(202.5, .topLeftQuarter, activeAngle)
                        AngleSelectorCircleSegment(247.5, .topHalf, activeAngle)
                        AngleSelectorCircleSegment(292.5, .topRightQuarter, activeAngle)
                    }
            }
    }
}

struct AngleSelectorRectangle: View {

    var isActive: Bool = false
    var isMaximize: Bool = false

    init(_ resizePosition: WindowDirection, _ activeResizePosition: WindowDirection) {
        if resizePosition == activeResizePosition {
            isActive = true
        } else {
            isActive = false
        }
    }

    var body: some View {
        Rectangle()
            .foregroundColor(isActive ? Color.black : Color.clear)
            .frame(width: 100/3, height: 100/3)
    }
}

struct AngleSelectorCircleSegment: View {

    var startingAngle: Double = 0
    var isActive: Bool = false
    var isMaximize: Bool = false

    init(_ angle: Double, _ resizePosition: WindowDirection, _ activeResizePosition: WindowDirection) {
        startingAngle = angle
        if resizePosition == activeResizePosition {
            isActive = true
        } else {
            isActive = false
        }
    }

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 50, y: 50))
            path.addArc(
                center: CGPoint(x: 50,
                                y: 50),
                radius: 90,
                startAngle: .degrees(startingAngle),
                endAngle: .degrees(startingAngle+45),
                clockwise: false
            )
        }
        .foregroundColor(isActive ? Color.black : Color.clear)
    }
}
