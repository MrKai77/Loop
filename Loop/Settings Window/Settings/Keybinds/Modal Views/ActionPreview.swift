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

    let action: WindowAction

    var body: some View {
        GeometryReader { proxy in
            let frame = frame(in: proxy)

            blurredWindow()
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
                .animation(luminareAnimation, value: frame)
        }
    }

    private func blurredWindow() -> some View {
        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(accentColorController.color1, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func frame(in proxy: GeometryProxy) -> CGRect {
        WindowFrameResolver.getFrame(
            for: action,
            bounds: CGRect(origin: .zero, size: proxy.size)
        )
    }
}
