//
//  KeybindCustomizationView.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-31.
//

import SwiftUI
import Defaults

struct KeybindCustomizationViewItem: View {
    @Binding var keybind: Keybind

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                keybind.direction.menuBarImage
                Text(keybind.direction.name)

                Spacer()

                Keycorder(key: $keybind.keybind)
//                Text("\(keybind.keybind.description)")
//                    .padding(5)
//                    .background {
//                        ZStack {
//                            RoundedRectangle(cornerRadius: 5)
//                                .foregroundStyle(.background.opacity(0.5))
//                            RoundedRectangle(cornerRadius: 5)
//                                .strokeBorder(.quaternary, lineWidth: 1)
//                        }
//                    }
            }
        }
        .padding(5)
        .padding(.leading, 5)
        .background(.quinary.opacity(0.5))
        .mask(RoundedRectangle(cornerRadius: 5))
        .background {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(.quaternary.opacity(0.7), lineWidth: 1)
        }
    }
}
