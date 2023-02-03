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
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
        self.sparkleAutomaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Updates")
                        .fontWeight(.medium)
                    Text("Current version: \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                Button("Check for Updates…", action: updater.checkForUpdates)
                    .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
                    .background(.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                
                HStack {
                    Text("Check for Updates Automatically")
                    Spacer()
                    Toggle("", isOn: self.$sparkleAutomaticallyChecksForUpdates)
                        .scaleEffect(0.7)
                        .toggleStyle(.switch)
                        .onChange(of: sparkleAutomaticallyChecksForUpdates) { newValue in
                            updater.automaticallyChecksForUpdates = newValue
                        }
                }
                .padding([.horizontal], 10)
            }
            .frame(height: 38)
        }
        .padding(20)
    }
}

// This view model class publishes when new updates can be checked by the user
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }
}
