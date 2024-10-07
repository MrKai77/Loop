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
    @ObservedObject var model: LuminareWindowModel = .shared

    @State var actionRect: CGRect = .zero
    @State private var scale: CGFloat = 1

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
    @State var isActive: Bool = true

    var body: some View {
        GeometryReader { geo in
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
                                    isActive ? primaryColor : .systemGray,
                                    isActive ? secondaryColor : .systemGray
                                ]
                            ),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: previewBorderThickness
                    )
            }
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
        .onChange(of: [customAccentColor, gradientColor]) { _ in
            recomputeColors()
        }
        .onChange(of: [useSystemAccentColor, useGradient]) { _ in
            recomputeColors()
        }
        .onReceive(.activeStateChanged) { notif in
            if let active = notif.object as? Bool {
                isActive = active
            }
        }
        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 10, topTrailingRadius: 10))
    }

    func recomputeColors() {
        withAnimation(LuminareConstants.animation) {
            primaryColor = Color.getLoopAccent(tone: .normal)
            secondaryColor = Color.getLoopAccent(tone: useGradient ? .darker : .normal)
        }
    }
}
