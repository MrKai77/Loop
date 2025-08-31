//
//  PreviewView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import Defaults
import SwiftUI

struct PreviewView: View {
    @Default(.previewPadding) var previewPadding
    @Default(.padding) var padding
    @Default(.previewCornerRadius) var previewCornerRadius
    @Default(.previewBorderThickness) var previewBorderThickness
    @Default(.animationConfiguration) var animationConfiguration

    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor
    @Default(.useGradient) var useGradient
    @Default(.gradientColor) var gradientColor

    @State var primaryColor: Color = .getLoopAccent(tone: .normal)
    @State var secondaryColor: Color = .getLoopAccent(tone: Defaults[.useGradient] ? .darker : .normal)

    var body: some View {
        GeometryReader { _ in
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .mask {
                        RoundedRectangle(cornerRadius: previewCornerRadius)
                            .foregroundColor(.white)
                    }

                RoundedRectangle(cornerRadius: previewCornerRadius)
                    .strokeBorder(.quinary, lineWidth: 1)

                RoundedRectangle(cornerRadius: previewCornerRadius)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(
                                colors: [
                                    primaryColor,
                                    secondaryColor
                                ]
                            ),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: previewBorderThickness
                    )
            }
            .padding(previewPadding + previewBorderThickness / 2)
        }
        // This would be called if the user's color mode is set to "wallpaper"
        .onChange(of: [customAccentColor, gradientColor]) { _ in
            recomputeColors()
        }
    }

    func recomputeColors() {
        primaryColor = Color.getLoopAccent(tone: .normal)
        secondaryColor = Color.getLoopAccent(tone: useGradient ? .darker : .normal)
    }
}
