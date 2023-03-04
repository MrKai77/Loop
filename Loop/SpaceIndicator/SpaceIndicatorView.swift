//
//  SpaceIndicatorView.swift
//  Loop
//
//  Created by Kai Azim on 2023-02-20.
//

import SwiftUI
import Defaults

struct SpaceIndicatorView: View {
    
    @State var activeSpace = 1
    @State var totalSpaces = 1
    
    @State var offset = 0
    
    // Color variables
    @Default(.loopUsesSystemAccentColor) var loopUsesSystemAccentColor
    @Default(.loopAccentColor) var loopAccentColor
    
    var body: some View {
        VStack {
            Spacer()
            
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .overlay {
                    HStack {
                        ForEach((1...self.totalSpaces), id: \.self) { space in
                            Circle()
                                .strokeBorder(self.loopUsesSystemAccentColor ? Color.accentColor : self.loopAccentColor,
                                              lineWidth: (space == self.activeSpace) ? 10 : 2)
                                .frame(width: 13, height: 13)
                        }
                    }
                }
                .frame(width: CGFloat(Double(21 * self.totalSpaces) + 19), height: 40)
                .cornerRadius(15)
                .shadow(radius: 10)
                .padding(10)
                .offset(y: CGFloat(self.offset))
                .animation(.interpolatingSpring(stiffness: 200, damping: 20), value: [self.activeSpace, self.offset])
        }
        .onReceive(.currentSpaceChanged) { obj in
            if let activeSpace = obj.userInfo?["Active"] as? Int {
                self.activeSpace = activeSpace
            }
            
            if let totalSpaces = obj.userInfo?["Total"] as? Int {
                self.totalSpaces = totalSpaces
            }
            
            self.offset = 0
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                self.offset = 50
            }
        }
        
    }
}
