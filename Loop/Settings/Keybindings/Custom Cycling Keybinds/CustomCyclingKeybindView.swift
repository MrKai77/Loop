//
//  CustomCyclingKeybindView.swift
//  Loop
//
//  Created by Kai Azim on 2023-12-27.
//

import SwiftUI

struct CustomCyclingKeybindView: View {
    @Binding var action: WindowAction
    @Binding var isSheetShown: Bool

    @FocusState private var focusedField: String?

    @State var cycleDirections: [WindowAction] = []
    @State private var selection: WindowAction?

    var body: some View {
        VStack {
            Form {
                Section {
                    VStack(spacing: 0) {
                        if self.cycleDirections.isEmpty {
                            HStack {
                                Spacer()
                                VStack {
                                    Text("Nothing to cycle through")
                                        .font(.title3)
                                    Text("Press + to add a cycle item!")
                                        .font(.caption)
                                }
                                Spacer()
                            }
                            .foregroundStyle(.secondary)
                            .padding()
                        }
                    }
                    .ignoresSafeArea()
                    .padding(-10)
                }
            }
            .onTapGesture {
                focusedField = nil
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
        }
        .frame(width: 450)
        .fixedSize(horizontal: false, vertical: true)
        .background(.background)
    }
}
