//
//  MoreSettingsView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-28.
//

import SwiftUI
import Sparkle

struct MoreSettingsView: View {
    
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater
    
    @State private var sparkleAutomaticallyChecksForUpdates: Bool
        
    init(updater: SPUUpdater) {
        self.updater = updater
        
        // Create our view model for our CheckForUpdatesView
        checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
        sparkleAutomaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
    }
    
    var body: some View {
        Form {
            Section(content: {
                Toggle("Check for Updates Automatically", isOn: $sparkleAutomaticallyChecksForUpdates)
                    .onChange(of: sparkleAutomaticallyChecksForUpdates) { newValue in
                        updater.automaticallyChecksForUpdates = newValue
                    }
            }, header: {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Updates")
                        Text("Current version: \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Check for Updates…", action: updater.checkForUpdates)
                        .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
                        .buttonStyle(.link)
                }
            })
        }
        .formStyle(.grouped)
    }
}

// This view model class publishes when new updates can be checked by the user
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }
}
