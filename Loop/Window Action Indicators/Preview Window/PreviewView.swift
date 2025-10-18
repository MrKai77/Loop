//
//  PreviewView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import Defaults
import SwiftUI

struct PreviewView: View {
    @Environment(\.luminareAnimation) var luminareAnimation
    @ObservedObject private var accentColorController: AccentColorController = .shared

    @Default(.previewPadding) var previewPadding
    @Default(.padding) var padding
    @Default(.previewCornerRadius) var previewCornerRadius
    @Default(.previewBorderThickness) var previewBorderThickness
    @Default(.animationConfiguration) var animationConfiguration

    var body: some View {
        GeometryReader { _ in
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(.rect(cornerRadius: previewCornerRadius))

                RoundedRectangle(cornerRadius: previewCornerRadius)
                    .strokeBorder(.quinary, lineWidth: 1)

                RoundedRectangle(cornerRadius: previewCornerRadius)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(
                                colors: [
                                    accentColorController.color1,
                                    accentColorController.color2
                                ]
                            ),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: previewBorderThickness
                    )
            }
            .padding(previewPadding + previewBorderThickness / 2)
            .animation(luminareAnimation, value: [accentColorController.color1, accentColorController.color2])
        }
    }
}
