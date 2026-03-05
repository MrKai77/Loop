//
//  WindowActionFramedPreview.swift
//  Loop
//
//  Created by Kai Azim on 2026-02-15.
//

import Luminare
import SwiftUI

struct WindowActionFramedPreview: View {
    @ObservedObject private var accentColorController: AccentColorController = .shared
    @Environment(\.luminareAnimation) private var luminareAnimation
    @State private var frame: CGRect = .zero
    let action: WindowAction

    var body: some View {
        ScreenView(isBlurred: action.sizeMode != .custom) {
            GeometryReader { geo in
                ZStack {
                    if action.sizeMode == .custom {
                        blurredWindow
                            .frame(width: frame.width, height: frame.height)
                            .offset(x: frame.origin.x, y: frame.origin.y)
                            .animation(luminareAnimation, value: frame)
                    }
                }
                .frame(
                    width: geo.size.width,
                    height: geo.size.height,
                    alignment: .topLeading
                )
                .onChange(of: action, initial: true) {
                    Task {
                        frame = await WindowFrameResolver.getFrame(
                            for: action,
                            window: nil,
                            bounds: CGRect(origin: .zero, size: geo.size)
                        )
                    }
                }
            }
        }
    }

    private var blurredWindow: some View {
        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
            .overlay {
                RoundedRectangle(cornerRadius: 12 - 5)
                    .strokeBorder(accentColorController.color1, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12 - 5))
    }
}
