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
            }
            .onTapGesture {
                focusedField = nil
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
        }
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .background(.background)
    }
}
