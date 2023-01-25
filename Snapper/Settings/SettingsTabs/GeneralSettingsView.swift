//
//  GeneralSettingsView.swift
//  Snapper
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults

struct GeneralSettingsView: View {
    
    @State private var selectedSnapperTrigger = "􀆪 Function"
    let snapperTriggerKeyOptions = [
        "􀆍 Left Control": 262401,
        "􀆕 Left Option": 524576,
        "􀆕 Right Option": 524608,
        "􀆔 Right Command": 1048848,
        "􀆡 Caps Lock": 270592,
        "􀆪 Function": 8388864]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Behavior")
                .fontWeight(.bold)
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
                RoundedRectangle(cornerRadius: 5)
                    .foregroundColor(Color(.systemGray).opacity(0.03))
                
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Trigger Snapper")
                            if (self.selectedSnapperTrigger == "􀆡 Caps Lock") {
                                Text("Remap Caps Lock to Control in System Settings.")
                                    .font(.caption)
                                    .opacity(0.5)
                            }
                        }
                        Spacer()
                        Picker("", selection: $selectedSnapperTrigger) {
                            ForEach(Array(snapperTriggerKeyOptions.keys), id: \.self) {
                                Text($0)
                            }
                        }
                        .frame(width: 160)
                    }
                    .onAppear {
                        for dictEntry in snapperTriggerKeyOptions {
                            if (dictEntry.value == Defaults[.snapperTrigger]) {
                                self.selectedSnapperTrigger = dictEntry.key
                            }
                        }
                    }
                    .onChange(of: self.selectedSnapperTrigger) { _ in
                        for dictEntry in snapperTriggerKeyOptions {
                            if (dictEntry.key == self.selectedSnapperTrigger) {
                                Defaults[.snapperTrigger] = dictEntry.value
                            }
                        }
                    }
                }
                .padding(10)
            }
        }
        .padding(20)
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView()
    }
}
