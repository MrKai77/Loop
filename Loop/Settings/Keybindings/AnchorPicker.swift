//
//  AnchorPicker.swift
//  Loop
//
//  Created by Kai Azim on 2023-12-24.
//

import SwiftUI

struct AnchorPicker: View {

    @Namespace private var animation
    @Binding var anchor: CustomKeybindAnchor?

    var body: some View {
        VStack {
            HStack {
                selectorCircle(.topLeft)
                Spacer()
                selectorCircle(.top)
                Spacer()
                selectorCircle(.topRight)
            }

            Spacer()

            HStack {
                selectorCircle(.left)
                Spacer()
                selectorCircle(.center)
                Spacer()
                selectorCircle(.right)
            }

            Spacer()

            HStack {
                selectorCircle(.bottomLeft)
                Spacer()
                selectorCircle(.bottom)
                Spacer()
                selectorCircle(.bottomRight)
            }
        }
        .animation(.snappy, value: self.anchor)
        .aspectRatio(16/10, contentMode: .fit)
        .padding(8)
        .background {
            if let screen = NSScreen.screenWithMouse,
               let url = NSWorkspace.shared.desktopImageURL(for: screen),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
    }

    @ViewBuilder
    func selectorCircle(_ anchor: CustomKeybindAnchor) -> some View {
        Button {
            self.anchor = anchor
        } label: {
            Circle()
                .foregroundStyle(Color.accentColor)
                .frame(width: 16, height: 16)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                }
                .overlay {
                    if self.anchor == anchor {
                        Circle()
                            .foregroundStyle(.white)
                            .frame(width: 6, height: 6)
                            .matchedGeometryEffect(id: "selection", in: animation)
                    }
                }
        }
        .buttonStyle(.plain)
        .shadow(radius: 10)
    }
}
