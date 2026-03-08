//
//  FileManager+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2026-02-25.
//

import Foundation

extension FileManager {
    /// Calculates the total size for a file or directory tree.
    func calculateDirectorySize(_ url: URL) throws -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }

        if !isDirectory.boolValue {
            let attributes = try attributesOfItem(atPath: url.path)
            return (attributes[.size] as? Int64) ?? 0
        }

        guard let enumerator = enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        return Int64(
            enumerator
                .compactMap { $0 as? URL }
                .compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
                .reduce(0, +)
        )
    }
}
