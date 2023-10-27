//
//  MenuBarIconView.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-20.
//

import SwiftUI

struct MenuBarIconView: View {
    @State var rotationAngle: Double = 0.0
    var body: some View {
        Image("loop")
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .rotationEffect(Angle.degrees(self.rotationAngle))
            .onReceive(.didLoop) { _ in
                self.rotationAngle = 0
                withAnimation(.interpolatingSpring(stiffness: 100, damping: 15)) {
                    self.rotationAngle += 360
                }
            }
    }
}
