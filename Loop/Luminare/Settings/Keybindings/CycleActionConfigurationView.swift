//
//  CycleActionConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-03.
//
// Still very WIP, don't use :)

import SwiftUI
import Luminare
import Defaults

struct CycleActionConfigurationView: View {
    @Binding var windowAction: WindowAction
    @Binding var isPresented: Bool

    @State private var action: WindowAction // this is so that onChange is called for each property

    @State private var selectedKeybinds = Set<WindowAction>()

    init(action: Binding<WindowAction>, isPresented: Binding<Bool>) {
        self._windowAction = action
        self._isPresented = isPresented
        self._action = State(initialValue: action.wrappedValue)
    }

    var body: some View {
        LuminareSection {
            LuminareTextField(
                Binding(
                    get: {
                        action.name ?? ""
                    },
                    set: {
                        action.name = $0
                    }
                ),
                placeHolder: "Cycle Keybind"
            )
        }

        LuminareList(
            items: Binding(
                get: {
                    if action.cycle == nil {
                        action.cycle = []
                    }

                    return action.cycle ?? []
                }, set: { newValue in
                    action.cycle = newValue
                }
            ),
            selection: $selectedKeybinds,
            addAction: {
                if action.cycle == nil {
                    action.cycle = []
                }

                self.action.cycle?.insert(.init(.noAction), at: 0)
            },
            content: { item in
                KeybindingItemView(
                    item,
                    cycleIndex: action.cycle?.firstIndex(of: item.wrappedValue)
                )
                .environmentObject(KeybindsConfigurationData())
            }
        )
        .onChange(of: action) { _ in
            windowAction = action
        }

        Button("Close") {
            isPresented = false
        }
        .buttonStyle(LuminareCompactButtonStyle())
    }
}
