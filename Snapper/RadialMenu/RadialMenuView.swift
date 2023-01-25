//
//  RadialMenuView.swift
//  Snapper
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI

struct RadialMenuView: View {
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    @State private var initialMousePosition: CGPoint = CGPoint()
    @State private var currentAngle:WindowSnappingOptions = .doNothing
    
    let activeColor = Color(.white).opacity(0.75)
    @State private var inactiveColor = Color(.clear)
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    
                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            Rectangle()
                                .frame(width: 100/3, height: 100/3)
                                .foregroundColor(self.currentAngle == .topLeftQuarter ? activeColor : inactiveColor)
                            
                            Rectangle()
                                .frame(width: 100/3, height: 100/3)
                                .foregroundColor(self.currentAngle == .leftHalf ? activeColor : inactiveColor)
                            
                            Rectangle()
                                .frame(width: 100/3, height: 100/3)
                                .foregroundColor(self.currentAngle == .bottomLeftQuarter ? activeColor : inactiveColor)
                        }
                        VStack(spacing: 0) {
                            Rectangle()
                                .frame(width: 100/3, height: 100/3)
                                .foregroundColor(self.currentAngle == .topHalf ? activeColor : inactiveColor)
                            
                            Spacer()
                                .frame(width: 100/3, height: 100/3)
                            
                            Rectangle()
                                .frame(width: 100/3, height: 100/3)
                                .foregroundColor(self.currentAngle == .bottomHalf ? activeColor : inactiveColor)
                        }
                        VStack(spacing: 0) {
                            Rectangle()
                                .frame(width: 100/3, height: 100/3)
                                .foregroundColor(self.currentAngle == .topRightQuarter ? activeColor : inactiveColor)
                            
                            Rectangle()
                                .frame(width: 100/3, height: 100/3)
                                .foregroundColor(self.currentAngle == .rightHalf ? activeColor : inactiveColor)
                            
                            Rectangle()
                                .frame(width: 100/3, height: 100/3)
                                .foregroundColor(self.currentAngle == .bottomRightQuarter ? activeColor : inactiveColor)
                        }
                    }
                }
                .mask(RoundedRectangle(cornerRadius: 30).strokeBorder(.black, lineWidth: 20))
                .frame(width: 100, height: 100)
                .shadow(radius: 10)
                
                .scaleEffect(self.currentAngle == .maximize ? 0.9 : 1)
                .animation(.interpolatingSpring(stiffness: 200, damping: 13), value: self.currentAngle)
                
                .onAppear {
                    self.initialMousePosition = CGPoint(x: NSEvent.mouseLocation.x,
                                                        y: NSEvent.mouseLocation.y)
                }
                .onReceive(timer) { input in
                    let angleToMouse = Angle(radians: initialMousePosition.angle(to: CGPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y)))
                    let distanceToMouse = initialMousePosition.distance(to: CGPoint(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y))
                    
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
                    } else if (distanceToMouse < 50) {
                        self.currentAngle = .doNothing
                        self.inactiveColor = Color(.clear)
                    } else {
                        self.currentAngle = .maximize
                        self.inactiveColor = activeColor
                    }
                }
                .onChange(of: self.currentAngle) { _ in
                    NSHapticFeedbackManager.defaultPerformer.perform(
                        NSHapticFeedbackManager.FeedbackPattern.alignment,
                        performanceTime: NSHapticFeedbackManager.PerformanceTime.now
                    )
                    
                    NotificationCenter.default.post(name: Notification.Name.currentSnappingDirectionChanged, object: nil, userInfo: ["Direction": self.currentAngle])
                }
                
                Spacer()
            }
            Spacer()
        }
    }
}
