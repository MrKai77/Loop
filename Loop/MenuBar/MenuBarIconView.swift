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
        // We don't use the symbol since it is *ever so slightly* off center. This is not a
        // problem with only Loop's symbol symbol, but the circle.circle SF symbol also is slightly
        // off center. Will need to investigate that later.
        Image(.menubarIcon)
            .rotationEffect(Angle.degrees(rotationAngle))
            .onReceive(.didLoop) { _ in
                rotationAngle = 0
                withAnimation(.interpolatingSpring(stiffness: 100, damping: 15)) {
                    rotationAngle += 360
                }
            }
    }
}
