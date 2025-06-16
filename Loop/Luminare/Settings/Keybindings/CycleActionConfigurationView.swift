//
//  CycleActionConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-03.
//

import Defaults
import Luminare
import SwiftUI

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
        VStack(spacing: 12) {
            LuminareSection(outerPadding: 0) {
                LuminareTextField("Cycle Keybind", text: Binding(get: { action.name ?? "" }, set: { action.name = $0 }))
                    .luminareHasBackground(false)
                    .luminareBordered(false)
                    .luminareAspectRatio(contentMode: .fill)
            }

            LuminareSection(outerPadding: 0) {
                HStack(spacing: 2) {
                    Button("Add") {
                        if action.cycle == nil {
                            action.cycle = []
                        }

                        action.cycle?.insert(.init(.noAction), at: 0)
                    }

                    Button("Remove", role: .destructive) {
                        action.cycle?.removeAll(where: { selectedKeybinds.contains($0) })
                    }
                    .disabled(selectedKeybinds.isEmpty)
                    .buttonStyle(.luminareProminent)
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
                    id: \.id
                ) { item in
                    KeybindItemView(
                        item,
                        cycleIndex: action.cycle?.firstIndex(of: item.wrappedValue)
                    )
                    .environmentObject(KeybindsConfigurationModel())
                } emptyView: {
                    HStack {
                        Spacer()
                        VStack {
                            Text("Nothing to cycle through")
                                .font(.title3)
                            Text("Press \"Add\" to add a cycle item")
                                .font(.caption)
                        }
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                    .padding()
                }
                .luminareListRoundedCorner(bottom: .always)
                .luminareListFixedHeight(until: .infinity)
            }
            .onChange(of: action) { _ in
                windowAction = action
            }

            Button("Close") {
                isPresented = false
            }
            .luminareAspectRatio(contentMode: .fill)
            .buttonStyle(.luminareCompact)
        }
    }
}
