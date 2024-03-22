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
                    TextField("Name", text: $action.name.bound, prompt: Text("Custom Keybind"))
                        .focused($focusedField, equals: "name")
                }

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
                                Text("Use MacOS Center")
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

                Section("Window Size") {
                    Picker("Mode", selection: $action.sizeMode) {
                        ForEach(CustomWindowActionSize.allCases) { system in
                            system.label
                                .tag(system as CustomWindowActionSize?)
                        }
                    }

                    if let sizeMode = action.sizeMode, sizeMode == .custom {
                        Picker("Configure using", selection: $action.measureSystem) {
                            ForEach(CustomWindowActionMeasureSystem.allCases) { system in
                                system.label
                                    .tag(system as CustomWindowActionMeasureSystem?)
                            }
                        }
                        .onChange(of: action.measureSystem) { _ in
                            if action.measureSystem == .percentage {
                                if action.width ?? 101 > 100 {
                                    self.action.width = 100
                                }
                                if action.height ?? 101 > 100 {
                                    self.action.height = 100
                                }
                            }
                        }

                        CrispValueAdjuster(
                            "Width",
                            value: Binding<Double>(
                                get: { self.action.width ?? 0 },
                                set: { self.action.width = $0 }
                            ),
                            sliderRange: action.measureSystem == .percentage ?  0...100 : 0...(
                                Double(NSScreen.main?.frame.width ?? 1000)
                            ),
                            postscript: action.measureSystem?.postscript ?? "",
                            lowerClamp: true
                        )

                        CrispValueAdjuster(
                            "Height",
                            value: Binding<Double>(
                                get: { self.action.height ?? 0 },
                                set: { self.action.height = $0 }
                            ),
                            sliderRange: action.measureSystem == .percentage ?  0...100 : 0...(
                                Double(NSScreen.main?.frame.height ?? 1000)
                            ),
                            postscript: action.measureSystem?.postscript ?? "",
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
            if self.action.sizeMode == nil {
                self.action.sizeMode = .custom
            }

            if self.action.measureSystem == nil {
                self.action.measureSystem = .percentage
            }

            if self.action.anchor == nil {
                self.action.anchor = .center
            }
        }
    }
}
