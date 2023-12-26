//
//  CustomKeybindView.swift
//  Loop
//
//  Created by Kai Azim on 2023-12-24.
//

import SwiftUI

struct CustomKeybindView: View {
    @Binding var keybind: Keybind
    @Binding var isSheetShown: Bool

    @FocusState private var focusedField: String?

    var body: some View {
        VStack {

            Form {
                Section {
                    TextField("Name", text: $keybind.name)
                        .focused($focusedField, equals: "name")
                }

                Section {
                    AnchorPicker(anchor: self.$keybind.anchor)
                        .ignoresSafeArea()
                        .padding(-10)
                }

                Section("Window Size") {
                    Picker("Configure using", selection: $keybind.measureSystem) {
                        ForEach(CustomKeybindMeasureSystem.allCases) { system in
                            system.label
                                .tag(system as CustomKeybindMeasureSystem?)
                        }
                    }
                    .onChange(of: keybind.measureSystem) { _ in
                        if keybind.measureSystem == .percentage {
                            if keybind.width ?? 101 > 100 {
                                self.keybind.width = 100
                            }
                            if keybind.height ?? 101 > 100 {
                                self.keybind.height = 100
                            }
                        }
                    }

                    HStack {
                        Stepper(
                            "Width",
                            value: Binding<Double>(
                                get: { self.keybind.width ?? 0 },
                                set: { self.keybind.width = $0 }
                            ),
                            in: keybind.measureSystem == .percentage ?  0...100 : 0...(.greatestFiniteMagnitude),
                            step: keybind.measureSystem == .percentage ?  10 : 100,
                            format: .number
                        )
                        .focused($focusedField, equals: "width")
                        Text(keybind.measureSystem?.postscript ?? "")
                    }

                    HStack {
                        Stepper(
                            "Height",
                            value: Binding<Double>(
                                get: { self.keybind.height ?? 0 },
                                set: { self.keybind.height = $0 }
                            ),
                            in: keybind.measureSystem == .percentage ?  0...100 : 0...(.greatestFiniteMagnitude),
                            step: keybind.measureSystem == .percentage ?  10 : 100,
                            format: .number
                        )
                        .focused($focusedField, equals: "height")
                        Text(keybind.measureSystem?.postscript ?? "")
                    }
                }

                Section {
                    HStack {
                        Text("Preview Size")
                        Spacer()
                        PreviewWindowButton(self.$keybind)
                    }
                }
            }
            .onTapGesture {
                focusedField = nil
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            HStack {
                Button {
                    isSheetShown = false
                } label: {
                    Text("Done")
                }
                .controlSize(.large)
            }
            .offset(y: -14)
        }
        .frame(width: 400)

        .onAppear {
            if self.keybind.measureSystem == nil {
                self.keybind.measureSystem = .percentage
            }

            if self.keybind.anchor == nil {
                self.keybind.anchor = .center
            }
        }
    }
}
