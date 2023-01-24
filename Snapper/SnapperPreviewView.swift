//
//  SnapperPreviewView.swift
//  Snapper
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI

struct SnapperPreviewView: View {
    
    @State var currentSnappingDirection: WindowSnappingOptions = .doNothing
    
    var body: some View {
        VStack {
            if (self.currentSnappingDirection == .south ||
                self.currentSnappingDirection == .southEast ||
                self.currentSnappingDirection == .southWest ||
                self.currentSnappingDirection == .doNothing) {
                Rectangle()
                    .foregroundColor(.clear)
            }
            
            HStack {
                
                if (self.currentSnappingDirection == .northEast ||
                    self.currentSnappingDirection == .east ||
                    self.currentSnappingDirection == .southEast ||
                    self.currentSnappingDirection == .doNothing) {
                    Rectangle()
                        .foregroundColor(.clear)
                }
                
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .mask(RoundedRectangle(cornerRadius: 15).foregroundColor(.white))
                    .shadow(radius: 10)
                    .padding(10)
                    .frame(width: self.currentSnappingDirection == .doNothing ? 0 : nil,
                           height: self.currentSnappingDirection == .doNothing ? 0 : nil)
                
                if (self.currentSnappingDirection == .northWest ||
                    self.currentSnappingDirection == .west ||
                    self.currentSnappingDirection == .southWest ||
                    self.currentSnappingDirection == .doNothing) {
                    Rectangle()
                        .foregroundColor(.clear)
                }
            }
            
            if (self.currentSnappingDirection == .north ||
                self.currentSnappingDirection == .northEast ||
                self.currentSnappingDirection == .northWest ||
                self.currentSnappingDirection == .doNothing) {
                Rectangle()
                    .foregroundColor(.clear)
            }
        }
        .animation(.interpolatingSpring(stiffness: 250, damping: 25), value: self.currentSnappingDirection)
        
        .onReceive(.currentSnappingDirectionChanged) { obj in
            if let direction = obj.userInfo?["Direction"] as? WindowSnappingOptions {
                self.currentSnappingDirection = direction
            }
        }
    }
}
