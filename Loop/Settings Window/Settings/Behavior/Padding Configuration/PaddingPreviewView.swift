//
//  PaddingPreviewView.swift
//  Loop
//
//  Created by Kai Azim on 2024-02-01.
//

import Luminare
import SwiftUI

struct PaddingPreviewView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation

    @Binding var model: PaddingModel

    init(_ paddingModel: Binding<PaddingModel>) {
        self._model = paddingModel
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                HStack(spacing: model.window / 2) {
                    blurredWindow()

                    VStack(spacing: model.window / 2) {
                        blurredWindow()
                        blurredWindow()
                    }
                }
                .padding(.top, model.totalTopPadding / 2)
                .padding(.bottom, model.bottom / 2)
                .padding(.leading, model.left / 2)
                .padding(.trailing, model.right / 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(luminareAnimation, value: model)
    }

    @ViewBuilder
    func blurredWindow() -> some View {
        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 2)
            }
            .clipShape(.rect(cornerRadius: 5))
    }
}
