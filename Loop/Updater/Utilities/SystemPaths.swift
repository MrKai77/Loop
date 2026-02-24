//
//  SystemPaths.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-23.
//

import Foundation

enum SystemPaths {
    static func isPath(_ url: URL, inside root: URL) -> Bool {
        let canonicalURL = canonical(url).path
        let canonicalRoot = canonical(root).path
        return canonicalURL == canonicalRoot || canonicalURL.hasPrefix("\(canonicalRoot)/")
    }

    static func isSamePath(_ lhs: URL, _ rhs: URL) -> Bool {
        canonical(lhs).path == canonical(rhs).path
    }

    private static let appSupportDirectory: URL = canonical(
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
    )

    static let loopDirectory: URL = canonical(
        appSupportDirectory.appendingPathComponent("Loop", isDirectory: true)
    )

    static let backupsDirectory: URL = canonical(
        loopDirectory.appendingPathComponent("Backups", isDirectory: true)
    )

    static let stagingDirectory: URL = canonical(
        loopDirectory.appendingPathComponent("Staging", isDirectory: true)
    )

    private static func canonical(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }
}
