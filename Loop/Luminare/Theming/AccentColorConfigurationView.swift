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
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.useGradient) var useGradient
    @Default(.customAccentColor) var customAccentColor
    @Default(.gradientColor) var gradientColor

    @State var showColorSection = false
    @State var showGradientSection = false

    var body: some View {
        LuminareSection {
            LuminarePicker(
                elements: [true, false],
                selection: Binding(
                    get: {
                        useSystemAccentColor
                    },
                   set: { newValue in
                       useSystemAccentColor = newValue

                       withAnimation(.smooth(duration: 0.25)) {
                           self.showColorSection = !useSystemAccentColor || (useGradient && !useSystemAccentColor)
                       }
                   }
                ),
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

            LuminareToggle(
                "Gradient",
                isOn: Binding(
                    get: {
                        useGradient
                    },
                    set: { newValue in
                        useGradient = newValue

                        withAnimation(.smooth(duration: 0.25)) {
                            showGradientSection = newValue
                        }
                    }
                )
            )
        }
        .onAppear {
            self.showColorSection = !useSystemAccentColor || (useGradient && !useSystemAccentColor)
        }

        VStack {
            if showColorSection {
                HStack {
                    Text("Color")
                    Spacer()
                }
                .foregroundStyle(.secondary)

                LuminareColorPicker(color: $customAccentColor)

                if showGradientSection {
                    LuminareColorPicker(color: $gradientColor)
                }
            }
        }
    }
}
