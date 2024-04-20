//
//  AccentColorConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import SwiftUI
import Luminare
import Defaults

struct AccentColorConfigurationView: View {
//    @Default(.useSystemAccentColor) var useSystemAccentColor
//    @Default(.customAccentColor) var customAccentColor
//    @Default(.useGradient) var useGradient
//    @Default(.gradientColor) var gradientColor

    @State var useSystemAccentColor = Defaults[.useSystemAccentColor] {
        didSet {
            Defaults[.useSystemAccentColor] = useSystemAccentColor
        }
    }

    @State var useGradient = Defaults[.useGradient] {
        didSet {
            Defaults[.useGradient] = useGradient
        }
    }

    @State var customAccentColor = Defaults[.customAccentColor] {
        didSet {
            Defaults[.customAccentColor] = customAccentColor
        }
    }

    var body: some View {
        LuminareSection {
            LuminarePicker(
                elements: [true, false],
                selection: $useSystemAccentColor,
                columns: 2,
                roundBottom: false
            ) { item in
                VStack {
                    Spacer()
                    Spacer()

                    if item {
                        Image(systemName: "apple.logo")
                    } else {
                        Image(systemName: "paintbrush.pointed")
                    }

                    Spacer()

                    Text(item ? "System" : "Custom")

                    Spacer()
                    Spacer()
                }
                .font(.title3)
                .frame(height: 90)
            }

            LuminareToggle("Gradient", isOn: $useGradient)
        }

        if !useSystemAccentColor || (useGradient && !useSystemAccentColor) {
            LuminareSection("Color") {
                if !useSystemAccentColor {
                    Text("TODO: CUSTOM ACCENT COLOR")
                }

                if useGradient && !useSystemAccentColor {
                    Text("TODO: CUSTOM GRADIENT COLOR (?)")
                }
            }
        }
    }
}
