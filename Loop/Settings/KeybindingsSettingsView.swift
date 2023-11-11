//
//  KeybindingsSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-28.
//

import Foundation

import SwiftUI
import Defaults

struct KeybindingsSettingsView: View {

    @Default(.keybinds) var keybinds
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor
    @Default(.preferMinimizeWithScrollDown) var preferMinimizeWithScrollDown

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                ForEach(self.$keybinds) { keybind in
                    KeybindCustomizationViewItem(keybind: keybind)
                }
                .padding(20)
            }

            Divider()

            Rectangle()
                .frame(height: 30)
                .foregroundStyle(.background)
                .overlay {
                    HStack {
                        Button("+") {
                            print("ADD NEW ITEM")
                        }

                        Spacer()

                        Button("Reset Defaults...") {
                            _keybinds.reset()
                        }
                    }
                    .padding(4)
                }
        }
        .frame(width: 490)
        .frame(maxHeight: 510)
    }
}
