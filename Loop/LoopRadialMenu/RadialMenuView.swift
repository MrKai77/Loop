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
    
    // Used to preview inside the app's settings
    @State var previewMode = false
    
    // Variable to store the initial position of the mouse
    @State private var initialMousePosition: CGPoint = CGPoint()
    
    // This is how often the current resize direction is refreshed
    @State var timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    // Data to be tracked using the timer
    @State private var currentResizeDirection: WindowResizingOptions = .noAction
    
    // Variables that store the radial menu's shape
    @Default(.loopRadialMenuCornerRadius) var loopRadialMenuCornerRadius
    @Default(.loopRadialMenuThickness) var loopRadialMenuThickness
    
    // Color variables
    @Default(.loopUsesSystemAccentColor) var loopUsesSystemAccentColor
    @Default(.loopAccentColor) var loopAccentColor
    @Default(.loopUsesAccentColorGradient) var loopUsesAccentColorGradient
    @Default(.loopAccentColorGradient) var loopAccentColorGradient
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                ZStack {
                    // NSVisualEffect on background
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    
                    // Used as the background when resize direction is .maximize
                    LinearGradient(
                        gradient: Gradient(colors: [
                            self.loopUsesSystemAccentColor ? Color.accentColor : self.loopAccentColor,
                            self.loopUsesSystemAccentColor ? Color.accentColor : self.loopUsesAccentColorGradient ? self.loopAccentColorGradient : self.loopAccentColor]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                    .opacity(self.currentResizeDirection == .maximize ? 1 : 0)
                    
                    // This rectangle with a gradient is masked with the current direction radial menu view
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                self.loopUsesSystemAccentColor ? Color.accentColor : self.loopAccentColor,
                                self.loopUsesSystemAccentColor ? Color.accentColor : self.loopUsesAccentColorGradient ? self.loopAccentColorGradient : self.loopAccentColor]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing)
                        )
                        .mask {
                            RadialMenu(activeAngle: self.currentResizeDirection)
                        }
                }
                // Mask the whole ZStack with the shape the user defines
                .mask {
                    RoundedRectangle(cornerRadius: self.loopRadialMenuCornerRadius)
                        .strokeBorder(.black, lineWidth: self.loopRadialMenuThickness)
                }
                .frame(width: 100, height: 100)
                
                Spacer()
            }
            Spacer()
        }
        .shadow(radius: 10)
        
        // Animate window
        .scaleEffect(self.currentResizeDirection == .maximize ? 0.8 : 1)
        .animation(.easeInOut, value: self.currentResizeDirection)
        
        // Get initial mouse position when window appears
        .onAppear {
            self.initialMousePosition = CGPoint(x: NSEvent.mouseLocation.x,
                                                y: NSEvent.mouseLocation.y)
            
            self.currentResizeDirection = .noAction
            NotificationCenter.default.post(name: Notification.Name.currentResizingDirectionChanged, object: nil, userInfo: ["Direction": self.currentResizeDirection])
            
            if (previewMode) {
                self.currentResizeDirection = .topHalf
            }
        }
        
        .onReceive(timer) { _ in
            if (!previewMode) {
                
                // Get angle & distance to mouse
                let angleToMouse = Angle(radians: initialMousePosition.angle(to: CGPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y)))
                let distanceToMouse = initialMousePosition.distanceSquared(to: CGPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y))
                
                // If mouse over 50 points away, select half or quarter positions
                if (distanceToMouse > pow(50-self.loopRadialMenuThickness, 2)) {
                    switch Int((angleToMouse.normalized().degrees+45/2)/45) {
                    case 0, 8: self.currentResizeDirection = .rightHalf
                    case 1:    self.currentResizeDirection = .bottomRightQuarter
                    case 2:    self.currentResizeDirection = .bottomHalf
                    case 3:    self.currentResizeDirection = .bottomLeftQuarter
                    case 4:    self.currentResizeDirection = .leftHalf
                    case 5:    self.currentResizeDirection = .topLeftQuarter
                    case 6:    self.currentResizeDirection = .topHalf
                    case 7:    self.currentResizeDirection = .topRightQuarter
                    default:   self.currentResizeDirection = .noAction
                    }
                    
                // If mouse is less than 10 points away, do nothing
                } else if (distanceToMouse < pow(10, 2)) {
                    self.currentResizeDirection = .noAction
                    
                // Otherwise, set position to maximize
                } else {
                    self.currentResizeDirection = .maximize
                }
            } else {
                self.currentResizeDirection = self.currentResizeDirection.next()
                
                if (self.currentResizeDirection == .rightThird) {
                    self.currentResizeDirection = .topHalf
                }
            }
        }
        // When current angle changes, send haptic feedback and post a notification which is used to position the preview window
        .onChange(of: self.currentResizeDirection) { _ in
            if (!previewMode) {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    NSHapticFeedbackManager.FeedbackPattern.alignment,
                    performanceTime: NSHapticFeedbackManager.PerformanceTime.now
                )
                
                NotificationCenter.default.post(name: Notification.Name.currentResizingDirectionChanged, object: nil, userInfo: ["Direction": self.currentResizeDirection])
            }
        }
    }
}

struct RadialMenu: View {
    
    @Default(.loopRadialMenuCornerRadius) var loopRadialMenuCornerRadius
    
    var activeAngle: WindowResizingOptions
    
    var body: some View {
            if (self.loopRadialMenuCornerRadius < 40) {
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
    
    init(_ resizePosition: WindowResizingOptions, _ activeResizePosition: WindowResizingOptions) {
        if (resizePosition == activeResizePosition) {
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
    
    init(_ angle: Double, _ resizePosition: WindowResizingOptions, _ activeResizePosition: WindowResizingOptions) {
        self.startingAngle = angle
        if (resizePosition == activeResizePosition) {
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
