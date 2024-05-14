//
//  PreviewView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults

struct PreviewView: View {
    let previewMode: Bool
    @State private var scale: CGFloat = 1

    init(previewMode: Bool = false) {
        self.previewMode = previewMode

        if previewMode {
            self._scale = State(initialValue: 0)
        }
    }

    @Default(.previewPadding) var previewPadding
    @Default(.padding) var padding
    @Default(.previewCornerRadius) var previewCornerRadius
    @Default(.previewBorderThickness) var previewBorderThickness
    @Default(.animationConfiguration) var animationConfiguration

    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor
    @Default(.useGradient) var useGradient
    @Default(.gradientColor) var gradientColor

    @State var primaryColor: Color = Color.getLoopAccent(tone: .normal)
    @State var secondaryColor: Color = Color.getLoopAccent(tone: Defaults[.useGradient] ? .darker : .normal)

    var body: some View {
        GeometryReader { _ in
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .mask {
                        RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous)
                            .foregroundColor(.white)
                    }

                RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous)
                    .strokeBorder(.quinary, lineWidth: 1)

                RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous)
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

            .scaleEffect(CGSize(width: scale, height: scale))
            .onAppear {
                if previewMode {
                    withAnimation(
                        .interpolatingSpring(
                            duration: 0.2,
                            bounce: 0.1,
                            initialVelocity: 1/2
                        )
                    ) {
                        self.scale = 1
                    }
                }
            }
        }
        .onChange(of: [customAccentColor, gradientColor]) { _ in
            recomputeColors()
        }
        .onChange(of: [useSystemAccentColor, useGradient]) { _ in
            recomputeColors()
        }
    }

    func recomputeColors() {
        withAnimation(.smooth(duration: 0.3)) {
            primaryColor = Color.getLoopAccent(tone: .normal)
            secondaryColor = Color.getLoopAccent(tone: useGradient ? .darker : .normal)
        }
    }
}
