//
//  PrivilegedInstallerError.swift
//  Loop
//
//  Created by Kai Azim on 2026-02-23.
//

import Foundation

enum PrivilegedInstallerError: LocalizedError {
    case ownershipLookupFailed(url: URL)
    case ownershipChangeFailed(url: URL, code: Int32)

    var errorDescription: String? {
        switch self {
        case let .ownershipLookupFailed(url):
            return "Could not resolve ownership for \(url.path)"
        case let .ownershipChangeFailed(url, code):
            let message = String(cString: strerror(code))
            return "Failed to set ownership for \(url.path): \(message) (\(code))"
        }
    }
}
