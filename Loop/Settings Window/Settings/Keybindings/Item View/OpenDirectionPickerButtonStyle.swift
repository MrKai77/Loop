//
//  OpenDirectionPickerButtonStyle.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-18.
//

import SwiftUI

struct OpenDirectionPickerButtonStyle: ButtonStyle {
    @Environment(\.luminareItemBeingHovered) private var luminareItemBeingHovered
    @Environment(\.luminareAnimationFast) private var luminareAnimationFast
    @Environment(\.isEnabled) private var isEnabled: Bool

    private let elementMinHeight: CGFloat = 25
    @State private var isHovering: Bool = false
    private let cornerRadius: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed || isHovering || luminareItemBeingHovered {
                    backgroundForState(isPressed: configuration.isPressed)
                        .background {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        }
                        .clipShape(.rect(cornerRadius: cornerRadius))
                        .padding(-4)
                }
            }
            .onHover { isHovering = $0 }
            .animation(luminareAnimationFast, value: [isHovering, luminareItemBeingHovered])
            .frame(minHeight: elementMinHeight)
            .opacity(isEnabled ? 1 : 0.5)
    }

    private func backgroundForState(isPressed: Bool) -> some View {
        Group {
            if isPressed {
                Rectangle().foregroundStyle(.quaternary)
            } else if isHovering {
                Rectangle().foregroundStyle(.quaternary.opacity(0.6))
            } else {
                Rectangle().foregroundStyle(.quinary.opacity(0.5))
            }
        }
    }
}
