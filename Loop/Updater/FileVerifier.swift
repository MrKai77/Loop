//
//  FileVerifier.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import CryptoKit
import Foundation
import Scribe

@Loggable(style: .static)
public class FileVerifier {
    private let config: UpdaterConfig
    private static let sha256Queue: DispatchQueue = .init(label: "com.loop.sha256", qos: .utility)

    public init(config: UpdaterConfig) {
        self.config = config
    }

    // MARK: - Public Async Methods

    public func verifyDownloadedFile(_ fileURL: URL, manifest: UpdateManifest) async throws {
        try await performVerification(
            operation: "downloaded file",
            fileURL: fileURL,
            expectedChecksum: manifest.checksums.zip,
            checksumType: "ZIP",
            calculator: { try await self.calculateSHA256($0) }
        )
    }

    public func verifyFileIntegrity(_ fileURL: URL, expectedChecksum: String) async throws -> Bool {
        let actualChecksum = try await calculateSHA256(fileURL)
        return actualChecksum.lowercased() == expectedChecksum.lowercased()
    }

    // MARK: - Public Sync Methods

    public func verifyDownloadedFileSync(_ fileURL: URL, manifest: UpdateManifest) throws {
        try performVerificationSync(
            operation: "downloaded file",
            fileURL: fileURL,
            expectedChecksum: manifest.checksums.zip,
            checksumType: "ZIP",
            calculator: { try self.calculateSHA256Sync($0) }
        )
    }

    // MARK: - Private Verification Helpers

    private func performVerification(
        operation: String,
        fileURL: URL,
        expectedChecksum: String,
        checksumType: String,
        calculator: (URL) async throws -> String
    ) async throws {
        Log.debug("Verifying \(operation) integrity - File URL: \(fileURL.path)")
        Log.debug("Starting \(checksumType) checksum calculation")
        let actualChecksum = try await calculator(fileURL)
        let isMatch = actualChecksum == expectedChecksum

        Log.debug("\(checksumType) checksum calculated - Match: \(isMatch)")

        guard isMatch else {
            Log.error("\(checksumType) checksum mismatch - File: \(fileURL.path)")
            throw UpdateError.checksumMismatch
        }

        Log.debug("\(operation.capitalized) verification completed successfully")
    }

    private func performVerificationSync(
        operation: String,
        fileURL: URL,
        expectedChecksum: String,
        checksumType: String,
        calculator: (URL) throws -> String
    ) throws {
        Log.debug("Verifying \(operation) integrity (sync) - File URL: \(fileURL.path), File Name: \(fileURL.lastPathComponent), Expected \(checksumType) Checksum: \(expectedChecksum)")
        Log.debug("Starting \(checksumType) checksum calculation")
        let actualChecksum = try calculator(fileURL)
        let isMatch = actualChecksum == expectedChecksum

        Log.debug("\(checksumType) checksum calculated - Calculated: \(actualChecksum), Expected: \(expectedChecksum), Match: \(isMatch)")

        guard isMatch else {
            Log.error("\(checksumType) checksum mismatch - Expected: \(expectedChecksum), Got: \(actualChecksum), File: \(fileURL.path)")
            throw UpdateError.checksumMismatch
        }

        Log.debug("\(operation.capitalized) verification completed successfully")
    }

    // MARK: - Checksum Calculation

    private func calculateSHA256(_ fileURL: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            Self.sha256Queue.async {
                do {
                    let checksum = try self.calculateSHA256Sync(fileURL)
                    continuation.resume(returning: checksum)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func calculateSHA256Sync(_ fileURL: URL) throws -> String {
        Log.debug("Calculating SHA256 for file - File: \(fileURL.path), Exists: \(FileManager.default.fileExists(atPath: fileURL.path))")

        let data = try Data(contentsOf: fileURL)
        Log.debug("File data loaded - Size: \(data.count) bytes, File: \(fileURL.lastPathComponent)")

        let digest = SHA256.hash(data: data)
        let checksum = digest.compactMap { String(format: "%02x", $0) }.joined()

        Log.debug("SHA256 calculation complete - Checksum: \(checksum), File: \(fileURL.lastPathComponent)")
        return checksum
    }

    private func findAppBundle(in directory: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        for item in contents {
            if item.pathExtension == "app" {
                Log.debug("Found app bundle - Path: \(item.path)")
                return item
            }

            let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory == true {
                if let found = try? findAppBundle(in: item) {
                    return found
                }
            }
        }

        throw UpdateError.installationError("Could not find .app bundle in extracted files")
    }

    private func verifyBundleStructure(_ appBundle: URL) throws {
        let requiredPaths = ["Contents/Info.plist", "Contents/MacOS"]

        for path in requiredPaths {
            let fullPath = appBundle.appendingPathComponent(path)
            guard FileManager.default.fileExists(atPath: fullPath.path) else {
                throw UpdateError.installationError("Missing required bundle component: \(path)")
            }
        }

        Log.info("Bundle structure verification passed")
    }

    private func verifyCodeSignature(_ appBundle: URL) async throws {
        Log.debug("Verifying code signature")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--verbose", appBundle.path]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            Log.warn("Code signature verification failed: \(output)")
        } else {
            Log.info("Code signature verification successful")
        }
    }
}
