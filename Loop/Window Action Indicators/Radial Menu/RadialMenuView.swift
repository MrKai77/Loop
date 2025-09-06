//
//  RadialMenuView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import Defaults
import Luminare
import SwiftUI

struct RadialMenuView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation
    @Environment(\.appearsActive) private var appearsActive
    @ObservedObject private var viewModel: RadialMenuViewModel
    private let radialMenuSize: CGFloat = 100

    @Default(.radialMenuCornerRadius) private var radialMenuCornerRadius
    @Default(.radialMenuThickness) private var radialMenuThickness
    @Default(.animationConfiguration) private var animationConfiguration
    @Default(.useSystemAccentColor) private var useSystemAccentColor
    @Default(.customAccentColor) private var customAccentColor
    @Default(.useGradient) private var useGradient
    @Default(.gradientColor) private var gradientColor

    init(viewModel: RadialMenuViewModel) {
        self.viewModel = viewModel
    }

    private var shouldAppearActive: Bool {
        !viewModel.previewMode || (viewModel.previewMode && appearsActive)
    }

    var body: some View {
        ZStack {
            ZStack {
                // NSVisualEffect on background
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

                // This rectangle with a gradient is masked with the current direction radial menu view
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(
                                colors: [
                                    shouldAppearActive ? viewModel.primaryColor : .systemGray,
                                    shouldAppearActive ? viewModel.secondaryColor : .systemGray
                                ]
                            ),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .mask(directionSelectorMask)

                radialMenuBorder()
            }
            .mask(radialMenuMask)

            overlayImage()
        }
        .frame(width: radialMenuSize, height: radialMenuSize)
        .shadow(radius: 10)
        .padding(20)
        .fixedSize()
        .scaleEffect(viewModel.radialMenuScale)
        .animation(animationConfiguration.radialMenuSize, value: viewModel.currentAction)
        .onChange(of: [customAccentColor, gradientColor]) { _ in viewModel.recomputeColors() }
        .onChange(of: [useSystemAccentColor, useGradient]) { _ in viewModel.recomputeColors() }
    }

    private func directionSelectorMask() -> some View {
        ZStack {
            if viewModel.shouldFillRadialMenu {
                Color.white
            }

            ZStack {
                if radialMenuCornerRadius >= radialMenuSize / 2 - 2 {
                    DirectionSelectorCircleSegment(
                        angle: viewModel.angle,
                        radialMenuSize: radialMenuSize
                    )
                } else {
                    DirectionSelectorSquareSegment(
                        angle: viewModel.angle,
                        radialMenuCornerRadius: radialMenuCornerRadius,
                        radialMenuThickness: radialMenuThickness
                    )
                }
            }
            .compositingGroup()
            .opacity(viewModel.shouldHideDirectionSelector ? 0 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func radialMenuBorder() -> some View {
        ZStack {
            if radialMenuCornerRadius >= radialMenuSize / 2 - 2 {
                Circle()
                    .stroke(.quinary, lineWidth: 2)

                Circle()
                    .stroke(.quinary, lineWidth: 2)
                    .padding(radialMenuThickness)
            } else {
                RoundedRectangle(cornerRadius: radialMenuCornerRadius)
                    .stroke(.quinary, lineWidth: 2)

                RoundedRectangle(cornerRadius: radialMenuCornerRadius - radialMenuThickness)
                    .stroke(.quinary, lineWidth: 2)
                    .padding(radialMenuThickness)
            }
        }
    }

    @ViewBuilder
    private func radialMenuMask() -> some View {
        ZStack {
            if radialMenuCornerRadius >= radialMenuSize / 2 - 2 {
                Circle()
                    .strokeBorder(.black, lineWidth: radialMenuThickness)
            } else {
                RoundedRectangle(cornerRadius: radialMenuCornerRadius)
                    .strokeBorder(.black, lineWidth: radialMenuThickness)
            }
        }
    }

    private func overlayImage() -> some View {
        Group {
            if viewModel.invalidWindowSelected {
                Image(systemName: "exclamationmark.triangle")
            } else if let image = viewModel.radialMenuImage {
                image
            }
        }
        .foregroundStyle(Color.getLoopAccent(tone: .normal))
        .font(.system(size: 20, weight: .bold))
    }
}
