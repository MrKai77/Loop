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
    @ObservedObject private var accentColorController: AccentColorController = .shared
    @ObservedObject private var viewModel: RadialMenuViewModel
    private let radialMenuSize: CGFloat = 100

    @Default(.radialMenuCornerRadius) private var radialMenuCornerRadius
    @Default(.radialMenuThickness) private var radialMenuThickness
    @Default(.animationConfiguration) private var animationConfiguration

    init(viewModel: RadialMenuViewModel) {
        self.viewModel = viewModel
    }

    private var shouldAppearActive: Bool {
        !viewModel.previewMode || (viewModel.previewMode && appearsActive)
    }

    var body: some View {
        ZStack {
            if #available(macOS 26.0, *) {
                postTahoeView()
            } else {
                preTahoeView()
            }
        }
        .padding(40)
        .fixedSize()
        .animation(animationConfiguration.radialMenuSize, value: viewModel.currentAction)
        .animation(luminareAnimation, value: [accentColorController.color1, accentColorController.color2])
        .onAppear {
            viewModel.setIsShown(true, animationDuration: viewModel.previewMode ? 0.0 : 0.1)
        }
    }

    @available(macOS 26.0, *)
    private func postTahoeView() -> some View {
        ZStack {
            GlassEffectContainer {
                if viewModel.isShown {
                    Color.clear
                        .glassEffect(
                            .regular.tint(accentColorController.color1.opacity(0.025)),
                            in: .rect(cornerRadius: radialMenuCornerRadius)
                                .inset(by: radialMenuThickness / 2)
                                .stroke(lineWidth: radialMenuThickness)
                        )
                        .glassEffectTransition(.materialize)
                }
            }

            if viewModel.isShown {
                ZStack {
                    radialMenuFill()
                        .mask(directionSelectorMask)
                        .mask(radialMenuMask)

                    overlayImage()
                }
                .transition(.scale(scale: 1.25).combined(with: .opacity))
            }
        }
        .frame(width: radialMenuSize, height: radialMenuSize)
        .shadow(color: .black.opacity(viewModel.isShadowShown ? 0.2 : 0), radius: 10)
        .scaleEffect(viewModel.shouldFillRadialMenu ? 0.85 : 1.0)
    }

    private func preTahoeView() -> some View {
        ZStack {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)

                radialMenuFill()
                    .mask(directionSelectorMask)

                radialMenuBorder()
            }
            .mask(radialMenuMask)

            overlayImage()
        }
        .frame(width: radialMenuSize, height: radialMenuSize)
        .shadow(radius: 10)
        .compositingGroup()
        .opacity(viewModel.isShown ? 1 : 0)
        .scaleEffect(viewModel.shouldFillRadialMenu ? 0.85 : 1.0)
    }

    private func radialMenuFill() -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(
                        colors: [
                            shouldAppearActive ? accentColorController.color1 : .systemGray,
                            shouldAppearActive ? accentColorController.color2 : .systemGray
                        ]
                    ),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func directionSelectorMask() -> some View {
        ZStack {
            if viewModel.shouldFillRadialMenu {
                Color.white
            } else {
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

    @ViewBuilder
    private func overlayImage() -> some View {
        if let image = viewModel.radialMenuImage {
            image
                .foregroundStyle(accentColorController.color1)
                .font(.system(size: 20, weight: .bold))
        }
    }
}
