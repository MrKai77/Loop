//
//  LuminarePreviewView.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-28.
//

import Defaults
import Luminare
import SwiftUI

struct LuminarePreviewView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation
    @Environment(\.appearsActive) private var appearsActive
    @ObservedObject var model: LuminareManager = .shared
    @ObservedObject private var accentColorController: AccentColorController = .shared

    @State var actionRect: CGRect = .zero
    @State private var scale: CGFloat = 1

    @Default(.previewPadding) var previewPadding
    @Default(.padding) var padding
    @Default(.previewCornerRadius) var previewCornerRadius
    @Default(.previewBorderThickness) var previewBorderThickness
    @Default(.animationConfiguration) var animationConfiguration

    var body: some View {
        GeometryReader { geo in
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
                                    appearsActive ? accentColorController.color1 : .systemGray,
                                    appearsActive ? accentColorController.color2 : .systemGray
                                ]
                            ),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: previewBorderThickness
                    )
            }
            .animation(luminareAnimation, value: [accentColorController.color1, accentColorController.color2])
            .padding(previewPadding + previewBorderThickness / 2)
            .frame(width: actionRect.width, height: actionRect.height)
            .offset(x: actionRect.minX, y: actionRect.minY)
            .scaleEffect(CGSize(width: scale, height: scale))
            .onAppear {
                actionRect = model.previewedAction.getFrame(window: nil, bounds: .init(origin: .zero, size: geo.size), isPreview: true)

                withAnimation(
                    .interpolatingSpring(
                        duration: 0.2,
                        bounce: 0.1,
                        initialVelocity: 1 / 2
                    )
                ) {
                    scale = 1
                }
            }
            .onChange(of: model.previewedAction) { _ in
                withAnimation(animationConfiguration.previewTimingFunctionSwiftUI) {
                    actionRect = model.previewedAction.getFrame(window: nil, bounds: .init(origin: .zero, size: geo.size))
                }
            }
        }
    }
}
