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
        
    init(updater: SPUUpdater) {
        self.updater = updater
        
        // Create our view model for our CheckForUpdatesView
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Updates")
                        .fontWeight(.medium)
                    Text("Current version: \(Bundle.main.appVersion) (build \(Bundle.main.appBuild))")
                        .font(.caption)
                        .opacity(0.6)
                }
                Spacer()
                Button("Check for Updates…", action: updater.checkForUpdates)
                    .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color("Monochrome").opacity(0.2), lineWidth: 0.5)
                RoundedRectangle(cornerRadius: 5)
                    .foregroundColor(Color("Monochrome").opacity(0.03))
                
                HStack {
                    Text("Check for Updates Automatically")
                    Spacer()
                }
                .padding([.horizontal], 10)
                .disabled(true)
                .opacity(0.5)
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
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}
