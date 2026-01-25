//
//  SystemPaths.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-23.
//

import Foundation

enum SystemPaths {
    private static let appSupportDirectory: URL = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first!

    static let loopDirectory: URL = appSupportDirectory.appendingPathComponent("Loop", isDirectory: true)
    static let backupsDirectory: URL = loopDirectory.appendingPathComponent("Backups", isDirectory: true)
}
