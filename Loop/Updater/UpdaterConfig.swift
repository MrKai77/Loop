//
//  UpdaterConfig.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import Foundation

// MARK: - Updater Configuration

/// Configuration for the Loop updater system
enum UpdaterConfigProvider {
    static var shared: UpdaterConfig {
        // Create a default configuration for Loop
        UpdaterConfig(
            updateEndpoint: URL(string: "https://api.github.com")!, // Base GitHub API URL
            currentBuildNumber: Bundle.main.appBuild ?? 0,
            userGroup: nil, // Can be set for A/B testing if needed
            networkConfig: .default
        )
    }
}
