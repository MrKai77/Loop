//
//  AccentColorConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import SwiftUI

class AccentColorConfigurationModel: ObservableObject {
    @Published var useSystemAccentColor = Defaults[.useSystemAccentColor] {
        didSet {
            Defaults[.useSystemAccentColor] = useSystemAccentColor
        }
    }

    @Published var useGradient = Defaults[.useGradient] {
        didSet {
            Defaults[.useGradient] = useGradient
        }
    }

    @Published var customAccentColor = Defaults[.customAccentColor] {
        didSet {
            Defaults[.customAccentColor] = customAccentColor
        }
    }

    @Published var gradientColor = Defaults[.gradientColor] {
        didSet {
            Defaults[.gradientColor] = gradientColor
        }
    }
}

struct AccentColorConfigurationView: View {
    @StateObject private var model = AccentColorConfigurationModel()

    var body: some View {
        LuminareSection {
            LuminarePicker(
                elements: [true, false],
                selection: $model.useSystemAccentColor.animation(.smooth(duration: 0.25)),
                columns: 2,
                roundBottom: false
            ) { item in
                VStack {
                    Spacer()
                    Spacer()

                    if item {
                        Image(systemName: "apple.logo")
                    } else {
                        Image(._18PxColorPalette)
                    }

                    Spacer()

                    Text(item ? "System" : "Custom")

                    Spacer()
                    Spacer()
                }
                .font(.title3)
                .frame(height: 90)
            }

            LuminareToggle("Gradient", isOn: $model.useGradient.animation(.smooth(duration: 0.25)))
        }

        VStack {
            if !model.useSystemAccentColor || (model.useGradient && !model.useSystemAccentColor) {
                HStack {
                    Text("Color")
                    Spacer()
                }
                .foregroundStyle(.secondary)

                LuminareColorPicker(color: $model.customAccentColor)

                if model.useGradient {
                    LuminareColorPicker(color: $model.gradientColor)
                }
            }
        }
    }
}
