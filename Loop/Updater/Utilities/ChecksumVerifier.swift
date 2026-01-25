//
//  ChecksumVerifier.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import CryptoKit
import Foundation
import Scribe

@Loggable(style: .static)
enum ChecksumVerifier {
    static func verifyFile(_ fileURL: URL, expectedChecksum: String) async throws {
        log.debug("Starting checksum calculation for file: \(fileURL.path)")
        let actualChecksum = try await calculateSHA256(fileURL)
        let isMatch = actualChecksum == expectedChecksum

        guard isMatch else {
            log.error("Checksum mismatch - File: \(fileURL.path)")
            throw UpdateError.checksumMismatch
        }

        log.debug("Checksum verification completed successfully")
    }

    @concurrent
    private static func calculateSHA256(_ fileURL: URL) async throws -> String {
        log.debug("Calculating SHA256 for file - File: \(fileURL.path), Exists: \(FileManager.default.fileExists(atPath: fileURL.path))")

        let data = try Data(contentsOf: fileURL)
        log.debug("File data loaded - Size: \(data.count) bytes, File: \(fileURL.lastPathComponent)")

        let digest = SHA256.hash(data: data)
        let checksum = digest.compactMap { String(format: "%02x", $0) }.joined()

        log.debug("SHA256 calculation complete - Checksum: \(checksum), File: \(fileURL.lastPathComponent)")
        return checksum
    }
}
