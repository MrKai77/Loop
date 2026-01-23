//
//  VersionDisplay.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-22.
//

import SwiftUI

struct VersionDisplay {
    let string: String
    let isPrerelease: Bool

    var display: String {
        if isPrerelease {
            "🧪 \(string)"
        } else {
            "\(string)"
        }
    }

    static let unknown = VersionDisplay(string: "Unknown", isPrerelease: false)

    static func formatCurrentAppVersion() -> VersionDisplay {
        // Read from the actual installed app's Info.plist, not the in-memory bundle

        guard let version = Bundle.main.appVersion,
              let build = Bundle.main.appBuild
        else {
            return .unknown
        }

        // Display version with emoji stripped for cleaner UI
        let devBuildEmoji = "🧪"
        let hasEmoji = version.contains(devBuildEmoji)
        let cleanVersion = version
            .replacingOccurrences(of: devBuildEmoji, with: "")
            .trimmingCharacters(in: .whitespaces)

        if hasEmoji {
            return VersionDisplay(string: "\(cleanVersion) (\(build))", isPrerelease: hasEmoji)
        } else {
            return VersionDisplay(string: cleanVersion, isPrerelease: hasEmoji)
        }
    }

    static func format(version: String?, build: Int?, isPrerelease: Bool) -> VersionDisplay {
        guard let version else {
            return .unknown
        }

        let devBuildEmoji = "🧪"
        let hasEmoji = version.contains(devBuildEmoji)
        let baseVersion = version
            .replacingOccurrences(of: devBuildEmoji, with: "")
            .trimmingCharacters(in: .whitespaces)

        var displayString = baseVersion

        if let build, hasEmoji || isPrerelease {
            displayString += " (\(build))"
        }

        return VersionDisplay(string: displayString, isPrerelease: hasEmoji || isPrerelease)
    }
}

extension UpdateManifest {
    func versionDisplay() -> VersionDisplay {
        VersionDisplay.format(
            version: version,
            build: buildNumber,
            isPrerelease: channel != .stable
        )
    }
}
