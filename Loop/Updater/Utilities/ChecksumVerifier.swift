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
    private static let chunkSize = 1_048_576 // 1 MiB

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
        let filePath = fileURL.path
        let fileManager = FileManager.default
        log.debug("Calculating SHA256 (streaming) for file: \(filePath)")

        guard fileManager.fileExists(atPath: filePath) else {
            throw UpdateError.installationFailed("Checksum validation failed: file not found at \(filePath)")
        }

        guard fileManager.isReadableFile(atPath: filePath) else {
            throw UpdateError.installationFailed("Checksum validation failed: file is not readable at \(filePath)")
        }

        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? fileHandle.close()
        }

        var hasher = SHA256()
        var totalBytesProcessed: Int64 = 0

        while true {
            let data = try fileHandle.read(upToCount: chunkSize) ?? Data()
            if data.isEmpty {
                break
            }

            hasher.update(data: data)
            totalBytesProcessed += Int64(data.count)
        }

        let digest = hasher.finalize()
        let checksum = digest.map { String(format: "%02x", $0) }.joined()

        log.debug("SHA256 calculation complete - Checksum: \(checksum), File: \(fileURL.lastPathComponent), Bytes: \(totalBytesProcessed)")
        return checksum
    }
}
