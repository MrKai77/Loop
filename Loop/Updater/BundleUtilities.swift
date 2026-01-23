//
//  BundleUtilities.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-23.
//

import Foundation
import Scribe

@Loggable(style: .static)
enum BundleUtilities {
    /// Required paths that must exist in a valid app bundle
    static let requiredBundlePaths = ["Contents/Info.plist", "Contents/MacOS"]

    /// Recursively searches for an app bundle (.app) within a directory
    /// - Parameter directory: The directory to search in
    /// - Returns: URL to the found app bundle
    /// - Throws: `UpdateError.installationError` if no app bundle is found
    static func findAppBundle(in directory: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        for item in contents {
            if item.pathExtension == "app" {
                log.info("Found app bundle: \(item.lastPathComponent)")
                return item
            }

            let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory == true,
               let found = try? findAppBundle(in: item) {
                return found
            }
        }

        let fileList = contents.map(\.lastPathComponent).joined(separator: ", ")
        log.error("No .app bundle found in directory. Available files: \(fileList)")

        throw UpdateError.installationError("No .app bundle found in update package. Found files: \(fileList)")
    }

    /// Verifies that a bundle has the required structure (Info.plist and MacOS directory)
    /// - Parameter bundleURL: URL to the app bundle to verify
    /// - Throws: `UpdateError.installationError` if required paths are missing
    static func verifyBundleStructure(_ bundleURL: URL) throws {
        log.debug("Verifying bundle structure for: \(bundleURL.lastPathComponent)")

        for path in requiredBundlePaths {
            let fullPath = bundleURL.appendingPathComponent(path)
            guard FileManager.default.fileExists(atPath: fullPath.path) else {
                log.error("Missing required path: \(path)")
                throw UpdateError.installationError("Invalid app bundle: missing \(path)")
            }
        }

        log.debug("Bundle structure verification passed")
    }
}
