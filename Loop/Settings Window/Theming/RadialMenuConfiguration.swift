//
//  RadialMenuConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import SwiftUI

struct RadialMenuConfigurationView: View {
    @Default(.radialMenuVisibility) private var radialMenuVisibility
    @Default(.radialMenuCornerRadius) private var radialMenuCornerRadius
    @Default(.radialMenuThickness) private var radialMenuThickness
    @Default(.radialMenuActions) private var radialMenuActions
    @State private var selectedRadialMenuActions: Set<RadialMenuWindowAction> = []

    var body: some View {
        LuminareSection {
            LuminareToggle("Radial menu", isOn: $radialMenuVisibility)

            if radialMenuVisibility {
                LuminareSlider(
                    "Corner radius",
                    value: $radialMenuCornerRadius.doubleBinding,
                    in: 30...50,
                    format: .number.precision(.fractionLength(0...0)),
                    clampsUpper: true,
                    clampsLower: true,
                    suffix: Text("px", comment: "Unit symbol: pixels")
                )
                .onChange(of: radialMenuCornerRadius) { _ in
                    if radialMenuCornerRadius - 1 < radialMenuThickness {
                        radialMenuThickness = radialMenuCornerRadius - 1
                    }
                }

                LuminareSlider(
                    "Thickness",
                    value: $radialMenuThickness.doubleBinding,
                    in: 10...35,
                    format: .number.precision(.fractionLength(0...0)),
                    clampsUpper: true,
                    clampsLower: true,
                    suffix: Text("px", comment: "Unit symbol: pixels")
                )
                .onChange(of: radialMenuThickness) { _ in
                    if radialMenuThickness + 1 > radialMenuCornerRadius {
                        radialMenuCornerRadius = radialMenuThickness + 1
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.25), value: radialMenuVisibility)

        LuminareSection(String(localized: "Actions", comment: "Section header shown in settings")) {
            HStack(spacing: 4) {
                Button("Add") {
                    radialMenuActions.insert(.custom(.init(.noAction)), at: 0)
                }
                .luminareRoundingBehavior(topLeading: true)

                Button("Remove", role: .destructive) {
                    radialMenuActions.removeAll(where: selectedRadialMenuActions.contains)
                }
                .luminareRoundingBehavior(topTrailing: true)
                .disabled(selectedRadialMenuActions.isEmpty)
                .keyboardShortcut(.delete)
            }

            LuminareList(
                items: $radialMenuActions,
                selection: $selectedRadialMenuActions,
                id: \.id
            ) { action in
                RadialMenuActionItemView(action)
            } emptyView: {
                HStack {
                    Spacer()
                    VStack {
                        Text("No radial menu actions")
                            .font(.title3)
                        Text("Press \"Add\" to add an action")
                            .font(.caption)
                    }
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding()
            }
            .luminareRoundingBehavior(bottom: true)
        }
    }
}
