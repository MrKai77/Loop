//
//  PreviewView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import Defaults
import SwiftUI

struct PreviewView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation
    @ObservedObject private var accentColorController: AccentColorController = .shared
    @ObservedObject private var viewModel: PreviewViewModel

    @Default(.previewPadding) private var previewPadding
    @Default(.padding) private var padding
    @Default(.previewCornerRadius) private var previewCornerRadius
    @Default(.previewBorderThickness) private var previewBorderThickness
    @Default(.animationConfiguration) private var animationConfiguration

    init(viewModel: PreviewViewModel) {
        self.viewModel = viewModel
    }

    private var cornerRadii: RectangleCornerRadii {
        viewModel.overrideCornerRadii?.inset(by: previewPadding) ?? RectangleCornerRadii(
            topLeading: previewCornerRadius,
            bottomLeading: previewCornerRadius,
            bottomTrailing: previewCornerRadius,
            topTrailing: previewCornerRadius
        )
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                    .clipShape(.rect(cornerRadii: cornerRadii))

                UnevenRoundedRectangle(cornerRadii: cornerRadii)
                    .strokeBorder(.quinary, lineWidth: 1)

                UnevenRoundedRectangle(cornerRadii: cornerRadii)
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
