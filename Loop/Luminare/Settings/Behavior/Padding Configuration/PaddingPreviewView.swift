//
//  PaddingPreviewView.swift
//  Loop
//
//  Created by Kai Azim on 2024-02-01.
//

import SwiftUI

struct PaddingPreviewView: View {
    @Binding var paddingModel: PaddingModel

    init(_ paddingModel: Binding<PaddingModel>) {
        self._paddingModel = paddingModel
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                HStack(spacing: paddingModel.window / 2) {
                    blurredWindow()

                    VStack(spacing: paddingModel.window / 2) {
                        blurredWindow()
                        blurredWindow()
                    }
                }
                .padding(.top, paddingModel.totalTopPadding / 2)
                .padding(.bottom, paddingModel.bottom / 2)
                .padding(.leading, paddingModel.left / 2)
                .padding(.trailing, paddingModel.right / 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(.smooth(duration: 0.25), value: paddingModel)
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
