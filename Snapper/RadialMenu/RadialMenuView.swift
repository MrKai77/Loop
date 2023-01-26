//
//  RadialMenuView.swift
//  Snapper
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Combine
import Defaults

struct RadialMenuView: View {
    // This is how often the current angle is refreshed
    @State private var timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    // Data to be tracked using the timer
    @State private var initialMousePosition: CGPoint = CGPoint()
    @State private var currentAngle: WindowSnappingOptions = .doNothing
    
    @Default(.snapperCornerRadius) var snapperCornerRadius
    @Default(.snapperThickness) var snapperThickness
    
    // Color variables
    @Default(.snapperUsesSystemAccentColor) var snapperUsesSystemAccentColor
    @Default(.snapperAccentColor) var snapperAccentColor
    @State private var inactiveColor = Color(.clear)    // This changes to the accent color when currentAngle's value is maximize
    
    // Used to preview inside the app's settings
    @State var previewMode = false
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                Group {
                    if (self.snapperCornerRadius < 40) {
                        // This is used when the user configures the radial menu to be a square
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                            .overlay {
                                HStack(spacing: 0) {
                                    VStack(spacing: 0) {
                                        angleSelectorRectangle(self.isAngleActive(.topLeftQuarter), self.getActiveColor(), self.inactiveColor)
                                        angleSelectorRectangle(self.isAngleActive(.leftHalf), self.getActiveColor(), self.inactiveColor)
                                        angleSelectorRectangle(self.isAngleActive(.bottomLeftQuarter), self.getActiveColor(), self.inactiveColor)
                                    }
                                    VStack(spacing: 0) {
                                        angleSelectorRectangle(self.isAngleActive(.topHalf), self.getActiveColor(), self.inactiveColor)
                                        Spacer().frame(width: 100/3, height: 100/3)
                                        angleSelectorRectangle(self.isAngleActive(.bottomHalf), self.getActiveColor(), self.inactiveColor)
                                    }
                                    VStack(spacing: 0) {
                                        angleSelectorRectangle(self.isAngleActive(.topRightQuarter), self.getActiveColor(), self.inactiveColor)
                                        angleSelectorRectangle(self.isAngleActive(.rightHalf), self.getActiveColor(), self.inactiveColor)
                                        angleSelectorRectangle(self.isAngleActive(.bottomRightQuarter), self.getActiveColor(), self.inactiveColor)
                                    }
                                }
                            }
                        
                    } else {
                        // This is used when the user configures the radial menu to be a circle
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                            .overlay {
                                angleSelectorCirclePart(-22.5, self.isAngleActive(.rightHalf), self.getActiveColor(), self.inactiveColor)
                                angleSelectorCirclePart(22.5, self.isAngleActive(.bottomRightQuarter), self.getActiveColor(), self.inactiveColor)
                                angleSelectorCirclePart(67.5, self.isAngleActive(.bottomHalf), self.getActiveColor(), self.inactiveColor)
                                angleSelectorCirclePart(112.5, self.isAngleActive(.bottomLeftQuarter), self.getActiveColor(), self.inactiveColor)
                                angleSelectorCirclePart(157.5, self.isAngleActive(.leftHalf), self.getActiveColor(), self.inactiveColor)
                                angleSelectorCirclePart(202.5, self.isAngleActive(.topLeftQuarter), self.getActiveColor(), self.inactiveColor)
                                angleSelectorCirclePart(247.5, self.isAngleActive(.topHalf), self.getActiveColor(), self.inactiveColor)
                                angleSelectorCirclePart(292.5, self.isAngleActive(.topRightQuarter), self.getActiveColor(), self.inactiveColor)
                            }
                    }
                }
                .frame(width: 100, height: 100)
                .mask(RoundedRectangle(cornerRadius: self.snapperCornerRadius).strokeBorder(.black, lineWidth: self.snapperThickness))
                
                Spacer()
            }
            Spacer()
        }
        .shadow(radius: 10)
        
        // Make window get smaller when selecting maximize (ironic haha)
        .scaleEffect(self.currentAngle == .maximize ? 0.9 : 1)
        .animation(.interpolatingSpring(stiffness: 200, damping: 13), value: self.currentAngle)
        
        // Get initial mouse position when window appears
        .onAppear {
            self.initialMousePosition = CGPoint(x: NSEvent.mouseLocation.x,
                                                y: NSEvent.mouseLocation.y)
        }
        
        .onReceive(timer) { input in
            if (!previewMode) {
                
                // Get angle & distance to mouse
                let angleToMouse = Angle(radians: initialMousePosition.angle(to: CGPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y)))
                let distanceToMouse = initialMousePosition.distance(to: CGPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y))
                
                // If mouse over 1000 units away, select half or quarter positions
                if (distanceToMouse > 1000) {
                    self.inactiveColor = Color(.clear)
                    
                    switch Int((angleToMouse.normalized().degrees+45/2)/45) {
                    case 0, 8: self.currentAngle = .rightHalf
                    case 1:    self.currentAngle = .bottomRightQuarter
                    case 2:    self.currentAngle = .bottomHalf
                    case 3:    self.currentAngle = .bottomLeftQuarter
                    case 4:    self.currentAngle = .leftHalf
                    case 5:    self.currentAngle = .topLeftQuarter
                    case 6:    self.currentAngle = .topHalf
                    case 7:    self.currentAngle = .topRightQuarter
                    default:   self.currentAngle = .doNothing
                    }
                    
                // If mouse is less than 50 units away, do nothing
                } else if (distanceToMouse < 50) {
                    self.currentAngle = .doNothing
                    self.inactiveColor = Color(.clear)
                    
                // Otherwise, set position to maximize
                } else {
                    self.currentAngle = .maximize
                    self.inactiveColor = self.snapperUsesSystemAccentColor ? Color.accentColor : self.snapperAccentColor
                }
            } else {
                // When in preview mode, always set angle to top half
                self.currentAngle = .topHalf
            }
        }
        
        // When current angle changes, send haptic feedback and post a notification which is used to position the preview window
        .onChange(of: self.currentAngle) { _ in
            if (!previewMode) {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    NSHapticFeedbackManager.FeedbackPattern.alignment,
                    performanceTime: NSHapticFeedbackManager.PerformanceTime.now
                )
                
                NotificationCenter.default.post(name: Notification.Name.currentSnappingDirectionChanged, object: nil, userInfo: ["Direction": self.currentAngle])
            }
        }
    }
    
    // Returns the active color. Pretty simple, but makes the main view more readable.
    func getActiveColor() -> Color {
        if self.snapperUsesSystemAccentColor {
            return Color.accentColor
        } else {
            return self.snapperAccentColor
        }
    }
    
    // Returns wether the inputted angle is acive. Again, pretty simple, but makes the main view more readable.
    func isAngleActive(_ angle: WindowSnappingOptions) -> Bool {
        if self.currentAngle == angle {
            return true
        } else {
            return false
        }
    }
}

struct angleSelectorRectangle: View {
    
    var active: Bool = false
    var activeColor: Color = Color.accentColor
    var inactiveColor: Color = Color.clear
    
    init(_ isActive: Bool, _ activeColor: Color, _ inactiveColor: Color) {
        self.active = isActive
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
    }
    
    var body: some View {
        Rectangle()
            .frame(width: 100/3, height: 100/3)
            .foregroundColor(self.active ? self.activeColor : self.inactiveColor)
    }
}

struct angleSelectorCirclePart: View {
    
    var startingAngle: Double = 0
    var active: Bool = false
    var activeColor: Color = Color.accentColor
    var inactiveColor: Color = Color.clear
    
    init(_ angle: Double, _ isActive: Bool, _ activeColor: Color, _ inactiveColor: Color) {
        self.startingAngle = angle
        self.active = isActive
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
    }
    
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 50, y: 50))
            path.addArc(center: CGPoint(x: 50, y: 50), radius: 90, startAngle: .degrees(startingAngle), endAngle: .degrees(startingAngle+45), clockwise: false)
        }
        .foregroundColor(self.active ? self.activeColor : self.inactiveColor)
    }
}
