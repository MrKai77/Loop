//
//  PreviewView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults

struct PreviewView: View {
    
    // Used to preview inside the app's settings
    @State var previewMode = false
    
    @State var currentResizingDirection: WindowDirection = .noAction
    
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.accentColor) var accentColor
    @Default(.useGradientAccentColor) var useGradientAccentColor
    @Default(.gradientAccentColor) var gradientAccentColor
    
    @Default(.previewVisibility) var previewVisibility
    @Default(.previewPadding) var previewPadding
    @Default(.previewCornerRadius) var previewCornerRadius
    @Default(.previewBorderThickness) var previewBorderThickness
    
    var body: some View {
        VStack {
            if currentResizingDirection == .bottomThird ||
               currentResizingDirection == .bottomHalf ||
               currentResizingDirection == .bottomRightQuarter ||
               currentResizingDirection == .bottomLeftQuarter ||
               currentResizingDirection == .noAction {
                Rectangle()
                    .foregroundColor(.clear)
            }
            
            HStack {
                
                if currentResizingDirection == .rightThird ||
                   currentResizingDirection == .topRightQuarter ||
                   currentResizingDirection == .rightHalf ||
                   currentResizingDirection == .bottomRightQuarter ||
                   currentResizingDirection == .noAction {
                    Rectangle()
                        .foregroundColor(.clear)
                }
                
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .mask(RoundedRectangle(cornerRadius: previewCornerRadius).foregroundColor(.white))
                        .shadow(radius: 10)
                    RoundedRectangle(cornerRadius: previewCornerRadius)
                        .stroke(LinearGradient(
                            gradient: Gradient(colors: [
                                useSystemAccentColor ? Color.accentColor : accentColor,
                                useSystemAccentColor ? Color.accentColor : useGradientAccentColor ? gradientAccentColor : accentColor]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing), lineWidth: previewBorderThickness)
                }
                .padding(previewPadding + previewBorderThickness/2)
                .frame(width: currentResizingDirection == .noAction ? 0 : nil,
                       height: currentResizingDirection == .noAction ? 0 : nil)
                
                if currentResizingDirection == .leftThird ||
                   currentResizingDirection == .topLeftQuarter ||
                   currentResizingDirection == .leftHalf ||
                   currentResizingDirection == .bottomLeftQuarter ||
                   currentResizingDirection == .noAction {
                    Rectangle()
                        .foregroundColor(.clear)
                }
            }
            
            if currentResizingDirection == .topThird ||
               currentResizingDirection == .topHalf ||
               currentResizingDirection == .topRightQuarter ||
               currentResizingDirection == .topLeftQuarter ||
               currentResizingDirection == .noAction {
                Rectangle()
                    .foregroundColor(.clear)
            }
        }
        .opacity(currentResizingDirection == .noAction ? 0 : 1)
        .animation(.interpolatingSpring(stiffness: 250, damping: 25), value: currentResizingDirection)
        .onReceive(.currentDirectionChanged) { obj in
            if !previewMode {
                if let direction = obj.userInfo?["Direction"] as? WindowDirection {
                    currentResizingDirection = direction
                }
            }
        }
        
        .onAppear {
            if previewMode {
                currentResizingDirection = .maximize
            }
        }
    }
}
