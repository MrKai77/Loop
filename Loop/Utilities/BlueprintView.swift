//
//  BlueprintView.swift
//  Loop
//
//  Created by Kai Azim on 2023-12-23.
//

import SwiftUI

struct BlueprintView: View {
    var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)

            if #available(macOS 14, *) {
                Rectangle()
                    .foregroundStyle(.white)
                    .colorEffect(
                        ShaderLibrary.grid(.float(10), .color(.gray.opacity(0.25)))
                    )
            }
        }
        .ignoresSafeArea()
        .padding(-10)
    }
}

#Preview {
    BlueprintView()
        .frame(width: 200, height: 200)
}
