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
        ZStack {
            HStack(spacing: paddingModel.window) {
                blurredWindow()

                VStack(spacing: paddingModel.window) {
                    blurredWindow()
                    blurredWindow()
                }
            }
            .padding(.top, paddingModel.top)
            .padding(.bottom, paddingModel.bottom)
            .padding(.leading, paddingModel.right)
            .padding(.trailing, paddingModel.left)
        }
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
