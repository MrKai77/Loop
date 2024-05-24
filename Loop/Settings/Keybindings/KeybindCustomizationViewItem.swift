//
//  KeybindCustomizationViewItem.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-31.
//

import SwiftUI
import Defaults

struct KeybindCustomizationViewItem: View {
    @Binding var keybind: WindowAction
    @Binding var triggerKey: Set<CGKeyCode>
    @State var showingInfo: Bool = false
    @State var isConfiguringCustomKeybind: Bool = false
    @State var isConfiguringCyclingKeybind: Bool = false

    var body: some View {
        HStack {
            if let moreInformation = self.keybind.direction.moreInformation {
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
        .padding(.vertical, 5)
    }
}
