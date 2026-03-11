//
//  ActionPreview.swift
//  Loop
//
//  Created by Kai Azim on 2026-03-09.
//

import Luminare
import SwiftUI

struct ActionPreview: View {
    @Environment(\.luminareAnimation) private var luminareAnimation
    @ObservedObject private var accentColorController: AccentColorController = .shared

    @State private var cachedFrame: CGRect = .zero
    let action: WindowAction

    var body: some View {
        GeometryReader { proxy in
            blurredWindow()
                .frame(width: cachedFrame.width, height: cachedFrame.height)
                .offset(x: cachedFrame.minX, y: cachedFrame.minY)
                .animation(luminareAnimation, value: cachedFrame)
                .onChange(of: action, initial: false) {
                    recomputeCachedFrame(size: proxy.size)
                }
                .onChange(of: proxy.size, initial: false) {
                    recomputeCachedFrame(size: proxy.size)
                }
        }
    }

    private func blurredWindow() -> some View {
        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
            .overlay {
                RoundedRectangle(cornerRadius: 12 - 5)
                    .strokeBorder(accentColorController.color1, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12 - 5))
    }

    private func recomputeCachedFrame(size: CGSize) {
        Task {
            cachedFrame = await WindowFrameResolver.getFrame(
                for: action,
                window: nil,
                bounds: CGRect(origin: .zero, size: size)
            )
        }
    }
}
