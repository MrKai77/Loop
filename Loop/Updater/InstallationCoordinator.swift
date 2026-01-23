//
//  InstallationCoordinator.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import Foundation
import Scribe

// MARK: - Installation Errors

enum InstallationError: LocalizedError {
    case swapVerificationFailed(String)

    var errorDescription: String? {
        switch self {
        case let .swapVerificationFailed(reason):
            "Atomic swap verification failed: \(reason)"
        }
    }
}

@Loggable
actor InstallationCoordinator {
    private let config: UpdaterConfig
    private let fileManager: FileManager
    private var isCancelled = false

    private lazy var backupDirectory: URL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Loop/Backups", isDirectory: true)

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    init(config: UpdaterConfig, fileManager: FileManager = .default) {
        self.config = config
        self.fileManager = fileManager
    }

    func performInstallation(from extractedURL: URL, manifest: UpdateManifest) async throws {
        log.info("Coordinating installation process")

        try checkCancellation()

        let appBundle = try findAppBundle(in: extractedURL)
        let currentAppURL = Bundle.main.bundleURL

        try await performAtomicInstallation(from: appBundle, to: currentAppURL, manifest: manifest)
    }

    func cancel() {
        log.info("Cancelling installation coordination")
        isCancelled = true
    }

    // MARK: - Private Installation Methods

    private func performAtomicInstallation(
        from sourceURL: URL,
        to destinationURL: URL,
        manifest: UpdateManifest
    ) async throws {
        log.info("Performing atomic installation")

        let stagingURL = destinationURL.appendingPathExtension("staging")

        do {
            try await executeInstallationSteps(
                source: sourceURL,
                staging: stagingURL,
                destination: destinationURL,
                manifest: manifest
            )
            log.info("Atomic installation completed successfully")
        } catch {
            await cleanupStaging(stagingURL)
            throw error
        }
    }

    private func executeInstallationSteps(
        source: URL,
        staging: URL,
        destination: URL,
        manifest: UpdateManifest
    ) async throws {
        try copyToStaging(from: source, to: staging)
        try await verifyStaged(staging, manifest: manifest)
        try await atomicSwap(staged: staging, current: destination)
    }

    private func copyToStaging(from sourceURL: URL, to stagingURL: URL) throws {
        try checkCancellation()

        log.debug("Copying application to staging area")

        if fileManager.fileExists(atPath: stagingURL.path) {
            try fileManager.removeItem(at: stagingURL)
        }
        try fileManager.copyItem(at: sourceURL, to: stagingURL)
    }

    private func verifyStaged(_ stagingURL: URL, manifest: UpdateManifest) async throws {
        try checkCancellation()

        log.debug("Verifying staged application")

        try verifyBundleStructure(stagingURL)

        try verifyVersionInfo(stagingURL, manifest: manifest)
        try await testStagedApplication(stagingURL)
    }

    private func atomicSwap(staged stagingURL: URL, current currentURL: URL) async throws {
        try checkCancellation()

        log.info("Starting atomic swap")
        log.info("Current app: \(currentURL.path)")
        log.info("Staged app: \(stagingURL.path)")

        try await manageBackups()
        let backupURL = try createBackup(from: currentURL)

        try performSwapOperation(
            current: currentURL,
            staged: stagingURL,
            backup: backupURL
        )
    }

    private func performSwapOperation(current: URL, staged: URL, backup: URL) throws {
        do {
            log.info("Moving current app to backup...")

            // Ensure the backup directory exists
            let backupParent = backup.deletingLastPathComponent()
            try fileManager.createDirectory(at: backupParent, withIntermediateDirectories: true)

            // Check if backup already exists and remove it if necessary
            if fileManager.fileExists(atPath: backup.path) {
                log.warn("Backup already exists at \(backup.path), removing it first")
                try fileManager.removeItem(at: backup)
            }

            try fileManager.moveItem(at: current, to: backup)
            log.info("Current app backed up to: \(backup.path)")

            log.info("Moving staged app to current location...")
            try fileManager.moveItem(at: staged, to: current)
            log.info("New app installed at: \(current.path)")

            // Verify the atomic swap was successful
            try verifySwapSuccess(current: current, backup: backup, staged: staged)
            log.info("Atomic swap completed and verified successfully!")
        } catch {
            log.error("Atomic swap failed: \(error)")
            log.error("Current: \(current.path), Staged: \(staged.path), Backup: \(backup.path)")
            log.error("Current exists: \(fileManager.fileExists(atPath: current.path))")
            log.error("Staged exists: \(fileManager.fileExists(atPath: staged.path))")
            log.error("Backup exists: \(fileManager.fileExists(atPath: backup.path))")

            try restoreFromBackup(current: current, backup: backup)
            throw error
        }
    }

    private func restoreFromBackup(current: URL, backup: URL) throws {
        guard fileManager.fileExists(atPath: backup.path) else { return }

        log.info("Attempting to restore from backup...")
        try? fileManager.removeItem(at: current)
        try? fileManager.moveItem(at: backup, to: current)
        log.info("Restored from backup")
    }

    // MARK: - Backup Management

    private func manageBackups() async throws {
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let backupSize = try calculateDirectorySize(backupDirectory)
        let maxBackupSize: Int64 = 104_857_600 // 100MB

        guard backupSize > maxBackupSize else { return }

        log.info("Backup directory exceeds 100MB (\(backupSize.formattedBytes)), cleaning up old backups")

        try await cleanupOldBackups(currentSize: backupSize, maxSize: maxBackupSize)
    }

    private func cleanupOldBackups(currentSize: Int64, maxSize: Int64) async throws {
        let backups = try getBackupsSortedByDate()
        var remainingSize = currentSize

        for (backupURL, _) in backups {
            guard remainingSize > maxSize else { break }

            let backupItemSize = try calculateDirectorySize(backupURL)
            try fileManager.removeItem(at: backupURL)
            remainingSize -= backupItemSize

            log.info("Removed old backup: \(backupURL.lastPathComponent) (\(backupItemSize.formattedBytes))")
        }

        log.info("Backup cleanup completed, new size: \(remainingSize.formattedBytes)")
    }

    private func getBackupsSortedByDate() throws -> [(URL, Date)] {
        try fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
        .compactMap { url -> (URL, Date)? in
            guard let date = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate else { return nil }
            return (url, date)
        }
        .sorted { $0.1 < $1.1 }
    }

    private func calculateDirectorySize(_ url: URL) throws -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }

        if !isDirectory.boolValue {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            return (attributes[.size] as? Int64) ?? 0
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        return Int64(enumerator
            .compactMap { $0 as? URL }
            .compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
            .reduce(0, +)
        )
    }

    private func createBackup(from _: URL) throws -> URL {
        let baseTimestamp = Self.dateFormatter.string(from: Date())
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        // Use "install" prefix to differentiate from RollbackManager backups
        var backupName = "install_backup_\(currentVersion)_\(baseTimestamp)"
        var backupURL = backupDirectory.appendingPathComponent(backupName)

        // If collision detected, add microseconds and retry up to 10 times
        var attempt = 0
        while fileManager.fileExists(atPath: backupURL.path), attempt < 10 {
            attempt += 1
            let microTimestamp = String(format: "%06d", Int(Date().timeIntervalSince1970 * 1_000_000) % 1_000_000)
            backupName = "install_backup_\(currentVersion)_\(baseTimestamp)_\(microTimestamp)"
            backupURL = backupDirectory.appendingPathComponent(backupName)
        }

        // Final check for collision
        guard !fileManager.fileExists(atPath: backupURL.path) else {
            throw UpdateError.installationError("Could not generate unique install backup name after \(attempt) attempts")
        }

        return backupURL
    }

    // MARK: - Verification Methods

    private func findAppBundle(in directory: URL) throws -> URL {
        let contents = try fileManager.contentsOfDirectory(
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
        log.error("No .app bundle found in extracted files. Available files: \(fileList)")

        throw UpdateError.installationError("No .app bundle found in update package. Found files: \(fileList)")
    }

    private func verifyBundleStructure(_ bundleURL: URL) throws {
        log.debug("Verifying bundle structure for: \(bundleURL.lastPathComponent)")

        let requiredPaths = ["Contents/Info.plist", "Contents/MacOS"]

        for path in requiredPaths {
            let fullPath = bundleURL.appendingPathComponent(path)
            guard fileManager.fileExists(atPath: fullPath.path) else {
                log.error("Missing required path: \(path)")
                throw UpdateError.installationError("Invalid app bundle: missing \(path)")
            }
        }

        log.debug("Bundle structure verification passed")
    }

    private func verifyVersionInfo(_ bundleURL: URL, manifest: UpdateManifest) throws {
        log.debug("Verifying version info")

        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        let (version, build) = try extractVersionInfo(from: infoPlistURL)

        log.info("Bundle version: \(version), build: \(build)")
        log.info("Expected version: \(manifest.version), build: \(manifest.buildNumber)")

        let normalizedAppVersion = version
            .replacing(/🧪/, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedAppVersion == manifest.version else {
            throw UpdateError.installationError("Version mismatch: expected: \(manifest.version), got \(version)")
        }
        
        if manifest.channel != .stable {
            guard build == manifest.buildNumber else {
                throw UpdateError.installationError("Build number mismatch: expected \(manifest.buildNumber), got: \(build)")
            }
        }

        log.debug("Version verification passed")
    }

    private func extractVersionInfo(from plistURL: URL) throws -> (version: String, build: Int) {
        guard let plist = NSDictionary(contentsOf: plistURL),
              let version = plist["CFBundleShortVersionString"] as? String,
              let buildString = plist["CFBundleVersion"] as? String,
              let build = Int(buildString) else {
            log.error("Could not read version info from Info.plist")
            throw UpdateError.installationError("Could not read version info from Info.plist")
        }
        return (version, build)
    }

    private func testStagedApplication(_ bundleURL: URL) async throws {
        log.debug("Testing staged application")

        let executablePath = bundleURL.appendingPathComponent("Contents/MacOS")
        let contents = try fileManager.contentsOfDirectory(
            at: executablePath,
            includingPropertiesForKeys: nil
        )

        guard !contents.isEmpty else {
            log.error("No executable found in MacOS directory")
            throw UpdateError.installationError("No executable found in app bundle")
        }

        log.debug("Application testing passed")
    }

    // MARK: - Utility Methods

    private func checkCancellation() throws {
        guard !isCancelled else {
            throw UpdateError.installationError("Installation was cancelled")
        }
    }

    // MARK: - Swap Verification

    private func verifySwapSuccess(current: URL, backup: URL, staged: URL) throws {
        log.debug("Verifying atomic swap success...")

        // 1. Verify backup was created successfully
        guard fileManager.fileExists(atPath: backup.path) else {
            throw InstallationError.swapVerificationFailed("Backup not found at expected location: \(backup.path)")
        }

        // Verify backup has correct bundle structure
        try verifyBundleStructure(backup)
        log.debug("Backup bundle structure verified")

        // Verify backup has a valid Info.plist and version
        let backupInfoPlistURL = backup.appendingPathComponent("Contents/Info.plist")
        guard fileManager.fileExists(atPath: backupInfoPlistURL.path) else {
            throw InstallationError.swapVerificationFailed("Backup app Info.plist not found")
        }

        guard let backupPlist = NSDictionary(contentsOf: backupInfoPlistURL),
              let backupVersion = backupPlist["CFBundleShortVersionString"] as? String,
              !backupVersion.isEmpty else {
            throw InstallationError.swapVerificationFailed("Backup app version information is invalid")
        }

        log.debug("Backup version verified: \(backupVersion)")

        // 2. Verify new app was installed successfully
        guard fileManager.fileExists(atPath: current.path) else {
            throw InstallationError.swapVerificationFailed("New app not found at expected location: \(current.path)")
        }

        // Verify new app has correct bundle structure
        try verifyBundleStructure(current)
        log.debug("New app bundle structure verified")

        // Verify new app has a valid Info.plist and version
        let infoPlistURL = current.appendingPathComponent("Contents/Info.plist")
        guard fileManager.fileExists(atPath: infoPlistURL.path) else {
            throw InstallationError.swapVerificationFailed("New app Info.plist not found")
        }

        guard let plist = NSDictionary(contentsOf: infoPlistURL),
              let version = plist["CFBundleShortVersionString"] as? String,
              !version.isEmpty else {
            throw InstallationError.swapVerificationFailed("New app version information is invalid")
        }

        log.debug("New app version verified: \(version)")

        // 3. Verify staging area is clean (should be empty after move)
        if fileManager.fileExists(atPath: staged.path) {
            log.warn("Staging area still exists (this is usually fine): \(staged.path)")
        }

        // 4. Verify file sizes are reasonable (basic sanity check)
        let backupAttributes = try fileManager.attributesOfItem(atPath: backup.path)
        let currentAttributes = try fileManager.attributesOfItem(atPath: current.path)

        guard let backupSize = backupAttributes[.size] as? Int64, backupSize > 0 else {
            throw InstallationError.swapVerificationFailed("Backup appears to be empty or invalid")
        }

        guard let currentSize = currentAttributes[.size] as? Int64, currentSize > 0 else {
            throw InstallationError.swapVerificationFailed("New app appears to be empty or invalid")
        }

        log.debug("File sizes verified - Backup: \(backupSize.formattedBytes), New: \(currentSize.formattedBytes)")
        log.debug("Atomic swap verification completed successfully")
    }

    private func cleanupStaging(_ stagingURL: URL) async {
        try? fileManager.removeItem(at: stagingURL)
    }
}
