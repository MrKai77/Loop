//
//  CustomKeybindView.swift
//  Loop
//
//  Created by Kai Azim on 2023-12-24.
//

import SwiftUI

struct CustomKeybindView: View {
    @Binding var action: WindowAction
    @Binding var isSheetShown: Bool
    @State var showingInfo: Bool = false

    @FocusState private var focusedField: String?

    var body: some View {
        VStack {
            Form {
                Section {
                    TextField("Name", text: $action.name.bound, prompt: Text("Custom keybind"))
                        .focused($focusedField, equals: "name")

                    Picker("Measurement unit", selection: $action.unit) {
                        ForEach(CustomWindowActionUnit.allCases) { system in
                            system.label
                                .tag(system as CustomWindowActionUnit?)
                        }
                    }
                    .onChange(of: action.unit) { _ in
                        if action.unit == .percentage {
                            if action.width ?? 101 > 100 {
                                self.action.width = 100
                            }
                            if action.height ?? 101 > 100 {
                                self.action.height = 100
                            }

                            if action.xPoint ?? 101 > 100 {
                                self.action.xPoint = 100
                            }
                            if action.yPoint ?? 101 > 100 {
                                self.action.xPoint = 100
                            }
                        }
                    }
                }

                Section {
                    Picker("Position mode", selection: $action.positionMode) {
                        ForEach(CustomWindowActionPositionMode.allCases) { system in
                            system.label
                                .tag(system as CustomWindowActionPositionMode?)
                        }
                    }

                    if let positionMode = action.positionMode, positionMode == .coordinates {
                        CrispValueAdjuster(
                            .init(localized: .init("Crisp Value Adjuster: X", defaultValue: "X")),
                            value: Binding<Double>(
                                get: {
                                    self.action.xPoint ?? 0
                                },
                                set: {
                                    self.action.xPoint = $0

                                    if let width = action.width,
                                       let sizeMode = action.sizeMode,
                                       sizeMode == .custom,
                                       let unit = action.unit,
                                       unit == .percentage {
                                        action.width = min(width, 100 - $0)
                                    }
                                }
                            ),
                            sliderRange: action.unit == .percentage ?  0...100 : 0...(
                                Double(NSScreen.main?.frame.width ?? 1000)
                            ),
                            postscript: action.unit?.suffix ?? "",
                            lowerClamp: true
                        )

                        CrispValueAdjuster(
                            .init(localized: .init("Crisp Value Adjuster: Y", defaultValue: "Y")),
                            value: Binding<Double>(
                                get: {
                                    self.action.yPoint ?? 0
                                },
                                set: {
                                    self.action.yPoint = $0

                                    if let height = action.height,
                                       let sizeMode = action.sizeMode,
                                       sizeMode == .custom,
                                       let unit = action.unit,
                                       unit == .percentage {
                                        action.height = min(height, 100 - $0)
                                    }
                                }
                            ),
                            sliderRange: action.unit == .percentage ?  0...100 : 0...(
                                Double(NSScreen.main?.frame.height ?? 1000)
                            ),
                            postscript: action.unit?.suffix ?? "",
                            lowerClamp: true
                        )
                    }
                } header: {
                    Text("Window position")
                } footer: {
                    if let positionMode = action.positionMode, positionMode == .coordinates {
                        Text("This point determines the upper-left edge of the window.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let positionMode = action.positionMode, positionMode == .generic {
                    Section {
                        ZStack {
                            WallpaperView().equatable()
                            AnchorPicker(anchor: self.$action.anchor)
                        }
                        .ignoresSafeArea()
                        .padding(-10)
                        .aspectRatio(16/10, contentMode: .fit)
                    }

                    if self.action.anchor == .center || self.action.anchor == .macOSCenter {
                        Section {
                            Toggle(
                                isOn: Binding(
                                    get: { self.action.anchor == .macOSCenter },
                                    set: { self.action.anchor = $0 ? .macOSCenter : .center }
                                )
                            ) {
                                HStack {
                                    Text("Use macOS Center")
                                    if let moreInformation = WindowDirection.macOSCenter.moreInformation {
                                        Button(action: {
                                            self.showingInfo.toggle()
                                        }, label: {
                                            Image(systemName: "info.circle")
                                                .font(.title3)
                                                .foregroundStyle(.secondary)
                                        })
                                        .buttonStyle(.plain)
                                        .popover(isPresented: $showingInfo, arrowEdge: .bottom) {
                                            Text(moreInformation)
                                                .multilineTextAlignment(.center)
                                                .padding(8)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Window size") {
                    Picker("Sizing mode", selection: $action.sizeMode) {
                        ForEach(CustomWindowActionSizeMode.allCases) { system in
                            system.label
                                .tag(system as CustomWindowActionSizeMode?)
                        }
                    }

                    if let sizeMode = action.sizeMode, sizeMode == .custom {
                        CrispValueAdjuster(
                            .init(localized: .init("Crisp Value Adjuster: Width", defaultValue: "Width")),
                            value: Binding<Double>(
                                get: {
                                    self.action.width ?? 0
                                },
                                set: {
                                    self.action.width = $0

                                    if let xPoint = action.xPoint,
                                       let positionMode = action.positionMode,
                                       positionMode == .coordinates,
                                       let unit = action.unit,
                                       unit == .percentage {
                                        action.xPoint = min(xPoint, 100 - $0)
                                    }
                                }
                            ),
                            sliderRange: action.unit == .percentage ?  0...100 : 0...(
                                Double(NSScreen.main?.frame.width ?? 1000)
                            ),
                            postscript: action.unit?.suffix ?? "",
                            lowerClamp: true
                        )

                        CrispValueAdjuster(
                            .init(localized: .init("Crisp Value Adjuster: Height", defaultValue: "Height")),
                            value: Binding<Double>(
                                get: {
                                    self.action.height ?? 0
                                },
                                set: {
                                    self.action.height = $0

                                    if let yPoint = action.yPoint,
                                       let positionMode = action.positionMode,
                                       positionMode == .coordinates,
                                       let unit = action.unit,
                                       unit == .percentage {
                                        action.yPoint = min(yPoint, 100 - $0)
                                    }
                                }
                            ),
                            sliderRange: action.unit == .percentage ?  0...100 : 0...(
                                Double(NSScreen.main?.frame.height ?? 1000)
                            ),
                            postscript: action.unit?.suffix ?? "",
                            lowerClamp: true
                        )
                    }
                }

                Section {
                    HStack {
                        Text("Preview window size")
                        Spacer()
                        PreviewWindowButton(self.$action)
                            .disabled({
                                if let sizeMode = action.sizeMode {
                                    return sizeMode != .custom
                                }
                                return false
                            }())
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
        .fixedSize(horizontal: false, vertical: true)
        .background(.background)

        .onAppear {
            if self.action.unit == nil {
                self.action.unit = .percentage
            }

            if self.action.sizeMode == nil {
                self.action.sizeMode = .custom
            }

            if self.action.positionMode == nil {
                self.action.positionMode = .generic
            }

            if self.action.anchor == nil {
                self.action.anchor = .center
            }
        }
    }
}
