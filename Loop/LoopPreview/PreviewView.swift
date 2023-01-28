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
            if (self.currentResizingDirection == .bottomThird ||
                self.currentResizingDirection == .bottomHalf ||
                self.currentResizingDirection == .bottomRightQuarter ||
                self.currentResizingDirection == .bottomLeftQuarter ||
                self.currentResizingDirection == .noAction) {
                Rectangle()
                    .foregroundColor(.clear)
            }
            
            HStack {
                
                if (self.currentResizingDirection == .rightThird ||
                    self.currentResizingDirection == .topRightQuarter ||
                    self.currentResizingDirection == .rightHalf ||
                    self.currentResizingDirection == .bottomRightQuarter ||
                    self.currentResizingDirection == .noAction) {
                    Rectangle()
                        .foregroundColor(.clear)
                }
                
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .mask(RoundedRectangle(cornerRadius: self.loopPreviewCornerRadius).foregroundColor(.white))
                        .shadow(radius: 10)
                    RoundedRectangle(cornerRadius: self.loopPreviewCornerRadius)
                        .stroke(LinearGradient(
                            gradient: Gradient(colors: [
                                self.loopUsesSystemAccentColor ? Color.accentColor : self.loopAccentColor,
                                self.loopUsesSystemAccentColor ? Color.accentColor : self.loopUsesAccentColorGradient ? self.loopAccentColorGradient : self.loopAccentColor]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing), lineWidth: self.loopPreviewBorderThickness)
                }
                .padding(self.loopPreviewPadding + self.loopPreviewBorderThickness/2)
                .frame(width: self.currentResizingDirection == .noAction ? 1 : nil,
                       height: self.currentResizingDirection == .noAction ? 1 : nil)
                .blur(radius: self.currentResizingDirection == .noAction ? 20 : 0)
                
                if (self.currentResizingDirection == .leftThird ||
                    self.currentResizingDirection == .topLeftQuarter ||
                    self.currentResizingDirection == .leftHalf ||
                    self.currentResizingDirection == .bottomLeftQuarter ||
                    self.currentResizingDirection == .noAction) {
                    Rectangle()
                        .foregroundColor(.clear)
                }
            }
            
            if (self.currentResizingDirection == .topThird ||
                self.currentResizingDirection == .topHalf ||
                self.currentResizingDirection == .topRightQuarter ||
                self.currentResizingDirection == .topLeftQuarter ||
                self.currentResizingDirection == .noAction) {
                Rectangle()
                    .foregroundColor(.clear)
            }
        }
        .animation(.interpolatingSpring(stiffness: 250, damping: 25), value: self.currentResizingDirection)
        
        .onReceive(.currentResizingDirectionChanged) { obj in
            if (!self.previewMode) {
                if let direction = obj.userInfo?["Direction"] as? WindowResizingOptions {
                    self.currentResizingDirection = direction
                }
            }
        }
        
        .onAppear {
            if (self.previewMode) {
                self.currentResizingDirection = .maximize
            }
        }
    }
}
