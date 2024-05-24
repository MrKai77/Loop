//
//  KeybindingsSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-28.
//

import SwiftUI
import Defaults

struct KeybindingsSettingsView: View {
    @Default(.keybinds) var keybinds
    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor

    @Default(.triggerKey) var triggerKey
    @Default(.doubleClickToTrigger) var doubleClickToTrigger
    @Default(.triggerDelay) var triggerDelay
    @Default(.middleClickTriggersLoop) var middleClickTriggersLoop

    @State private var suggestAddingTriggerDelay: Bool = false
    @State private var selection = Set<WindowAction>()

    var body: some View {
        ZStack {
            Form {
                Section {
                    VStack(spacing: 0) {
                        if self.keybinds.isEmpty {
                            HStack {
                                Spacer()
                                VStack {
                                    Text("No keybinds")
                                        .font(.title3)
                                    Text("Press + to add a keybind!")
                                        .font(.caption)
                                }
                                Spacer()
                            }
                            .foregroundStyle(.secondary)
                            .padding()
                        }
                    }
                } header: {
                    Text("Keybinds")
                }
            }
            .formStyle(.grouped)
        }
    }
}
