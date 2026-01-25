//
//  VersionDisplay.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-22.
//

import SwiftUI

struct VersionDisplay {
    let shortDisplay: String
    let fullDisplay: String
    let isPrerelease: Bool

    static let unknown: VersionDisplay = .init(shortDisplay: "Unknown", fullDisplay: "Unknown", isPrerelease: false)

    static let current: VersionDisplay = {
        guard let version = Bundle.main.appVersion,
              let build = Bundle.main.appBuild
        else {
            return .unknown
        }

        #if !RELEASE
            return .format(version: version, build: build, isPrerelease: true)
        #else
            return .format(version: version, build: build, isPrerelease: false)
        #endif
    }()

    static func format(version: String?, build: Int?, isPrerelease: Bool) -> VersionDisplay {
        guard let version else {
            return .unknown
        }

        let devBuildEmoji = "🧪"
        let shouldTreatAsPrerelease = isPrerelease || version.contains(devBuildEmoji)

        let buildString = if let build { "(\(build))" } else { "" }

        let baseVersion = version
            .replacing(devBuildEmoji, with: "")
            .trimmingCharacters(in: .whitespaces)

        let shortDisplay: String = if shouldTreatAsPrerelease {
            "🧪 \(baseVersion) \(buildString)"
        } else {
            baseVersion
        }

        let fullDisplay = if shouldTreatAsPrerelease {
            "🧪 \(baseVersion) \(buildString)"
        } else {
            "\(baseVersion) \(buildString)" // Always show build number
        }

        return VersionDisplay(
            shortDisplay: shortDisplay,
            fullDisplay: fullDisplay,
            isPrerelease: shouldTreatAsPrerelease
        )
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
