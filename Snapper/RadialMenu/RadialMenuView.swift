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
    
    // Used to preview inside the app's settings
    @State var previewMode = false
    
    // This is how often the current angle is refreshed
    @State var timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    // Data to be tracked using the timer
    @State private var initialMousePosition: CGPoint = CGPoint()
    @State private var currentAngle: WindowSnappingOptions = .noAction
    
    @Default(.snapperCornerRadius) var snapperCornerRadius
    @Default(.snapperThickness) var snapperThickness
    
    // Color variables
    @Default(.snapperUsesSystemAccentColor) var snapperUsesSystemAccentColor
    @Default(.snapperAccentColor) var snapperAccentColor
    @Default(.snapperAccentColorUseGradient) var snapperAccentColorUseGradient
    @Default(.snapperAccentColorGradient) var snapperAccentColorGradient
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    
                    LinearGradient(
                        gradient: Gradient(colors: [
                            self.snapperUsesSystemAccentColor ? Color.accentColor : self.snapperAccentColor,
                            self.snapperUsesSystemAccentColor ? Color.accentColor : self.snapperAccentColorUseGradient ? self.snapperAccentColorGradient : self.snapperAccentColor]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                    .opacity(self.currentAngle == .maximize ? 1 : 0)
                    
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                self.snapperUsesSystemAccentColor ? Color.accentColor : self.snapperAccentColor,
                                self.snapperUsesSystemAccentColor ? Color.accentColor : self.snapperAccentColorUseGradient ? self.snapperAccentColorGradient : self.snapperAccentColor]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing)
                        )
                        .mask {
                            RadialMenu(activeAngle: self.currentAngle)
                        }
                }
                .frame(width: 100, height: 100)
                .mask {
                    RoundedRectangle(cornerRadius: self.snapperCornerRadius)
                        .strokeBorder(.black, lineWidth: self.snapperThickness)
                }
                .blur(radius: self.currentAngle == .noAction ? 5 : 0)
                
                Spacer()
            }
            Spacer()
        }
        .shadow(radius: self.currentAngle == .noAction ? 0 : 10)
        
        // Make window get smaller when selecting maximize (ironic haha)
        .scaleEffect(self.currentAngle == .maximize ? 0.9 : 1)
        .animation(.easeOut, value: self.currentAngle)
        
        // Get initial mouse position when window appears
        .onAppear {
            self.initialMousePosition = CGPoint(x: NSEvent.mouseLocation.x,
                                                y: NSEvent.mouseLocation.y)
            
            self.currentAngle = .noAction
            NotificationCenter.default.post(name: Notification.Name.currentSnappingDirectionChanged, object: nil, userInfo: ["Direction": self.currentAngle])
            
            if (previewMode) {
                self.currentAngle = .topHalf
            }
        }
        
        .onReceive(timer) { input in
            if (!previewMode) {
                
                // Get angle & distance to mouse
                let angleToMouse = Angle(radians: initialMousePosition.angle(to: CGPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y)))
                let distanceToMouse = initialMousePosition.distanceSquared(to: CGPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y))
                
                // If mouse over 1000 units away, select half or quarter positions
                if (distanceToMouse > pow(50-self.snapperThickness, 2)) {
                    switch Int((angleToMouse.normalized().degrees+45/2)/45) {
                    case 0, 8: self.currentAngle = .rightHalf
                    case 1:    self.currentAngle = .bottomRightQuarter
                    case 2:    self.currentAngle = .bottomHalf
                    case 3:    self.currentAngle = .bottomLeftQuarter
                    case 4:    self.currentAngle = .leftHalf
                    case 5:    self.currentAngle = .topLeftQuarter
                    case 6:    self.currentAngle = .topHalf
                    case 7:    self.currentAngle = .topRightQuarter
                    default:   self.currentAngle = .noAction
                    }
                    
                // If mouse is less than 50 units away, do nothing
                } else if (distanceToMouse < pow(10, 2)) {
                    self.currentAngle = .noAction
                    
                // Otherwise, set position to maximize
                } else {
                    self.currentAngle = .maximize
                }
            } else {
                self.currentAngle = self.currentAngle.next()
                
                if (self.currentAngle == .rightThird) {
                    self.currentAngle = .topHalf
                }
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
}

struct RadialMenu: View {
    
    @Default(.snapperCornerRadius) var snapperCornerRadius
    @Default(.snapperThickness) var snapperThickness
    
    var activeAngle: WindowSnappingOptions
    
    var body: some View {
            if (self.snapperCornerRadius < 40) {
                // This is used when the user configures the radial menu to be a square
                Color.clear
                    .overlay {
                        HStack(spacing: 0) {
                            VStack(spacing: 0) {
                                angleSelectorRectangle(.topLeftQuarter, self.activeAngle)
                                angleSelectorRectangle(.leftHalf, self.activeAngle)
                                angleSelectorRectangle(.bottomLeftQuarter, self.activeAngle)
                            }
                            VStack(spacing: 0) {
                                angleSelectorRectangle(.topHalf, self.activeAngle)
                                Spacer().frame(width: 100/3, height: 100/3)
                                angleSelectorRectangle(.bottomHalf, self.activeAngle)
                            }
                            VStack(spacing: 0) {
                                angleSelectorRectangle(.topRightQuarter, self.activeAngle)
                                angleSelectorRectangle(.rightHalf, self.activeAngle)
                                angleSelectorRectangle(.bottomRightQuarter, self.activeAngle)
                            }
                        }
                    }

            } else {
                // This is used when the user configures the radial menu to be a circle
                Color.clear
                    .overlay {
                        angleSelectorCirclePart(-22.5, .rightHalf, self.activeAngle)
                        angleSelectorCirclePart(22.5, .bottomRightQuarter, self.activeAngle)
                        angleSelectorCirclePart(67.5, .bottomHalf, self.activeAngle)
                        angleSelectorCirclePart(112.5, .bottomLeftQuarter, self.activeAngle)
                        angleSelectorCirclePart(157.5, .leftHalf, self.activeAngle)
                        angleSelectorCirclePart(202.5, .topLeftQuarter, self.activeAngle)
                        angleSelectorCirclePart(247.5, .topHalf, self.activeAngle)
                        angleSelectorCirclePart(292.5, .topRightQuarter, self.activeAngle)
                    }
            }
    }
}

struct angleSelectorRectangle: View {
    
    var isActive: Bool = false
    var isMaximize: Bool = false
    
    init(_ snapPosition: WindowSnappingOptions, _ currentSnapPosition: WindowSnappingOptions) {
        if (snapPosition == currentSnapPosition) {
            self.isActive = true
        } else {
            self.isActive = false
        }
    }
    
    var body: some View {
        Rectangle()
            .foregroundColor(self.isActive ? Color.black : Color.clear)
            .frame(width: 100/3, height: 100/3)
    }
}

struct angleSelectorCirclePart: View {
    
    var startingAngle: Double = 0
    var isActive: Bool = false
    var isMaximize: Bool = false
    
    init(_ angle: Double, _ snapPosition: WindowSnappingOptions, _ currentSnapPosition: WindowSnappingOptions) {
        self.startingAngle = angle
        if (snapPosition == currentSnapPosition) {
            self.isActive = true
        } else {
            self.isActive = false
        }
    }
    
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 50, y: 50))
            path.addArc(center: CGPoint(x: 50, y: 50), radius: 90, startAngle: .degrees(startingAngle), endAngle: .degrees(startingAngle+45), clockwise: false)
        }
        .foregroundColor(self.isActive ? Color.black : Color.clear)
    }
}
