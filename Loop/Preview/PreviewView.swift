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
    
    @State var currentResizingDirection: WindowResizingOptions = .noAction
    
    @Default(.loopUsesSystemAccentColor) var loopUsesSystemAccentColor
    @Default(.loopAccentColor) var loopAccentColor
    @Default(.loopUsesAccentColorGradient) var loopUsesAccentColorGradient
    @Default(.loopAccentColorGradient) var loopAccentColorGradient
    
    @Default(.loopPreviewVisibility) var loopPreviewVisibility
    @Default(.loopPreviewPadding) var loopPreviewPadding
    @Default(.loopPreviewCornerRadius) var loopPreviewCornerRadius
    @Default(.loopPreviewBorderThickness) var loopPreviewBorderThickness
    
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
                        .mask(RoundedRectangle(cornerRadius: loopPreviewCornerRadius).foregroundColor(.white))
                        .shadow(radius: 10)
                    RoundedRectangle(cornerRadius: loopPreviewCornerRadius)
                        .stroke(LinearGradient(
                            gradient: Gradient(colors: [
                                loopUsesSystemAccentColor ? Color.accentColor : loopAccentColor,
                                loopUsesSystemAccentColor ? Color.accentColor : loopUsesAccentColorGradient ? loopAccentColorGradient : loopAccentColor]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing), lineWidth: loopPreviewBorderThickness)
                }
                .padding(loopPreviewPadding + loopPreviewBorderThickness/2)
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
        .onReceive(.currentResizingDirectionChanged) { obj in
            if !previewMode {
                if let direction = obj.userInfo?["Direction"] as? WindowResizingOptions {
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
