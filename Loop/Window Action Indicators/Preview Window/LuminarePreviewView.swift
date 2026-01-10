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
    @EnvironmentObject private var windowModel: SettingsWindowManager
    @ObservedObject private var accentColorController: AccentColorController = .shared

    @State var actionRect: CGRect = .zero

    @Default(.previewPadding) var previewPadding
    @Default(.padding) var padding
    @Default(.previewCornerRadius) var previewCornerRadius
    @Default(.previewBorderThickness) var previewBorderThickness
    @Default(.animationConfiguration) var animationConfiguration

    var body: some View {
        GeometryReader { geo in
            PreviewView(viewModel: PreviewViewModel(window: nil))
                .frame(width: actionRect.width, height: actionRect.height)
                .offset(x: actionRect.minX, y: actionRect.minY)
                .opacity(actionRect.size.area == .zero ? 0 : 1)
                .onChange(
                    of: windowModel.previewedAction,
                    initial: true
                ) { newAction in
                    let newActionRect: CGRect = if newAction.willManipulateExistingWindowFrame {
                        .init(
                            x: geo.size.width / 2,
                            y: geo.size.height / 2,
                            width: 0,
                            height: 0
                        )
                    } else {
                        newAction.getFrame(
                            window: nil,
                            bounds: .init(origin: .zero, size: geo.size),
                            isPreview: true
                        )
                    }

                    if actionRect == .zero {
                        actionRect = newActionRect
                    } else {
                        withAnimation(animationConfiguration.previewTimingFunctionSwiftUI) {
                            actionRect = newActionRect
                        }
                    }
                }
        }
    }
}
