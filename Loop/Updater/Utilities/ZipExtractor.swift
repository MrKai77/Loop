//
//  ZipExtractor.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-23.
//

import Foundation
import Scribe
import ZIPFoundation

@Loggable(style: .static)
enum ZipExtractor {
    /// Extracts a ZIP file to a temporary directory
    /// - Parameters:
    ///   - zipURL: URL of the ZIP file to extract
    ///   - cancellationCheck: Optional closure to check if operation should be cancelled
    /// - Returns: URL of the temporary directory containing extracted contents
    /// - Throws: `UpdateError` if extraction fails
    static func extract(
        from zipURL: URL,
        cancellationCheck: (() throws -> ())? = nil
    ) throws -> URL {
        log.info("Extracting update from: \(zipURL.path)")

        try validateZipFile(zipURL)

        let tempDir = createTemporaryDirectory()

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try performExtraction(from: zipURL, to: tempDir, cancellationCheck: cancellationCheck)
            try verifyExtractionContainsAppBundle(tempDir)
            return tempDir
        } catch {
            // Clean up on failure
            try? FileManager.default.removeItem(at: tempDir)
            throw error
        }
    }

    // MARK: - Validation

    private static func validateZipFile(_ zipURL: URL) throws {
        log.debug("Validating ZIP file: \(zipURL.path)")

        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw createError("ZIP file not found", zipURL: zipURL)
        }

        guard FileManager.default.isReadableFile(atPath: zipURL.path) else {
            throw createError("ZIP file is not readable", zipURL: zipURL)
        }

        // Verify ZIP magic bytes (PK signature)
        let fileHandle = try FileHandle(forReadingFrom: zipURL)
        defer { fileHandle.closeFile() }

        let headerData = fileHandle.readData(ofLength: 4)
        guard headerData.count >= 2 else {
            throw createError("File is too small to be a valid ZIP archive", zipURL: zipURL)
        }

        let (pk1, pk2) = (headerData[0], headerData[1])
        guard pk1 == 0x50, pk2 == 0x4B else {
            throw createError("File is not a valid ZIP archive (invalid signature)", zipURL: zipURL)
        }

        log.debug("ZIP file validation passed")
    }

    // MARK: - Extraction

    private static func performExtraction(
        from zipURL: URL,
        to destinationURL: URL,
        cancellationCheck: (() throws -> ())?
    ) throws {
        log.info("Extracting ZIP archive: \(zipURL.lastPathComponent)")

        let archive = try Archive(url: zipURL, accessMode: .read)

        for entry in archive where !entry.path.contains(/__MACOSX/) {
            try cancellationCheck?()
            _ = try archive.extract(entry, to: destinationURL.appendingPathComponent(entry.path))
        }

        log.success("Successfully extracted ZIP archive")
    }

    private static func verifyExtractionContainsAppBundle(_ extractedURL: URL) throws {
        log.debug("Verifying extraction contains app bundle")

        // This will throw if no app bundle is found
        let appBundle = try BundleUtilities.findAppBundle(in: extractedURL)
        try BundleUtilities.verifyBundleStructure(appBundle)

        log.debug("Extraction verification passed")
    }

    // MARK: - Utilities

    private static func createTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("LoopExtraction_\(UUID().uuidString)")
    }

    private static func createError(_ message: String, zipURL: URL? = nil) -> UpdateError {
        var fullMessage = message
        if let zipURL {
            let fileSize = try? FileManager.default.attributesOfItem(atPath: zipURL.path)[.size] as? Int64
            let fileSizeString = fileSize?.formattedBytes ?? "unknown size"
            fullMessage = "\(message) at \(zipURL.path) (Size: \(fileSizeString))"
        }
        return .installationFailed(fullMessage)
    }
}
