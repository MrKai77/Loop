//
//  UpdateInstaller.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import AppKit
import Foundation
import Scribe
import ZIPFoundation

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
actor UpdateInstaller {
    // MARK: - Types

    typealias ProgressHandler = @Sendable (UpdateProgress) -> ()

    // MARK: - Properties

    private let config: UpdaterConfig
    private let fileVerifier: FileVerifier
    private let fileManager: FileManager

    private var isCancelled = false
    private var installationState: InstallationState = .idle

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
        self.fileVerifier = FileVerifier(config: config)
    }

    func installUpdate(from downloadURL: URL, manifest: UpdateManifest) async throws {
        log.info("Starting installation of update: \(manifest.version)")

        try await performPreInstallationChecks(manifest: manifest)

        do {
            installationState = .inProgress
            try await executeInstallationSequence(downloadURL: downloadURL, manifest: manifest)
            installationState = .completed
            log.success("Installation completed successfully")
        } catch {
            installationState = .failed
            log.error("Installation failed: \(error)")
            throw UpdateError.installationError(error.localizedDescription)
        }
    }

    func installUpdateWithProgress(
        from downloadURL: URL,
        manifest: UpdateManifest,
        progressHandler: ProgressHandler? = nil
    ) async throws {
        log.info("Starting installation with progress tracking")

        let steps: [(phase: UpdateProgress.UpdatePhase, progress: Double, operation: () async throws -> ())] = [
            (.checking, 0.1, { try await self.performPreInstallationChecks(manifest: manifest) }),
            (.downloading, 0.3, { try await self.verifyDownloadIntegrity(downloadURL, manifest: manifest) }),
            (.extracting, 0.6, {}),
            (.verifying, 0.8, {}),
            (.installing, 0.9, {}),
            (.verifying, 0.95, {})
        ]

        var extractedURL: URL?

        do {
            installationState = .inProgress

            for (index, step) in steps.enumerated() {
                try checkCancellation()
                progressHandler?(UpdateProgress(phase: step.phase, percentage: step.progress))

                if index == 2 { // Extract step
                    extractedURL = try await extractAndVerifyUpdate(downloadURL)
                } else if index == 3 { // Verify extraction step
                    guard let url = extractedURL else { throw createSafetyError("No extracted URL available") }
                    try await verifyExtractionIntegrity(url, manifest: manifest)
                } else if index == 4 { // Install step
                    guard let url = extractedURL else { throw createSafetyError("No extracted URL available") }
                    try await performSafeInstallation(from: url, manifest: manifest)
                } else if index == 5 { // Final verification step
                    try await performComprehensiveVerification(manifest: manifest)
                } else {
                    try await step.operation()
                }
            }

            // Cleanup
            if let url = extractedURL {
                try await performSafeCleanup(url, downloadURL)
            }

            installationState = .completed
            progressHandler?(UpdateProgress(phase: .completed, percentage: 1.0))
            log.success("Installation with progress completed successfully")

        } catch {
            installationState = .failed
            log.error("Installation failed during step: \(error)")

            if let url = extractedURL {
                try await performSafeCleanup(url, downloadURL)
            }

            throw UpdateError.installationError(error.localizedDescription)
        }
    }

    func restartApplication() {
        log.info("Preparing application restart")

        // Final verification before restart
        do {
            try performPreRestartSafetyChecks()
        } catch {
            log.error("Pre-restart verification failed: \(error)")
            // Don't restart if verification fails
            return
        }

        let appURL = Bundle.main.bundleURL

        // Verify the app exists before attempting restart
        guard fileManager.fileExists(atPath: appURL.path) else {
            log.error("Application not found at path before restart: \(appURL.path)")
            return
        }

        log.info("Pre-restart verification passed, proceeding with restart")

        Task {
            try? await Task.sleep(for: .seconds(1))

            log.info("Attempting application restart")
            try await NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }

        Task {
            try? await Task.sleep(for: .seconds(0.5))

            log.info("Terminating current process")
            await NSApplication.shared.terminate(nil)
        }
    }

    func cancel() async {
        log.warn("Cancelling installation")
        isCancelled = true
        installationState = .cancelled
    }

    // MARK: - Installation Methods

    private func executeInstallationSequence(downloadURL: URL, manifest: UpdateManifest) async throws {
        let extractedURL = try await performInstallationSequenceSteps(downloadURL: downloadURL, manifest: manifest)
        try await performSafeCleanup(extractedURL, downloadURL)
    }

    private func performInstallationSequenceSteps(downloadURL: URL, manifest: UpdateManifest) async throws -> URL {
        // Step 1: Verify download integrity
        try await verifyDownloadIntegrity(downloadURL, manifest: manifest)

        // Step 2: Extract and verify
        let extractedURL = try await extractAndVerifyUpdate(downloadURL)

        // Step 3: Verify extraction integrity
        try await verifyExtractionIntegrity(extractedURL, manifest: manifest)

        // Step 4: Perform safe installation
        try await performSafeInstallation(from: extractedURL, manifest: manifest)

        // Step 5: Comprehensive verification
        try await performComprehensiveVerification(manifest: manifest)

        return extractedURL
    }

    // MARK: - Pre-Installation Safety Checks

    private func performPreInstallationChecks(manifest: UpdateManifest) async throws {
        log.info("Performing pre-installation safety checks")

        try checkCancellation()

        let checks: [(String, () async throws -> ())] = [
            ("disk space", { try await self.verifyDiskSpace(manifest: manifest) }),
            ("current app integrity", { try await self.verifyCurrentAppIntegrity() }),
            ("installation permissions", { try await self.verifyInstallationPermissions() }),
            ("conflicting processes", { try await self.checkForConflictingRunningProcesses() })
        ]

        for (checkName, check) in checks {
            do {
                try await check()
                log.debug("\(checkName) check passed")
            } catch {
                log.error("\(checkName) check failed: \(error)")
                throw error
            }
        }

        log.success("All pre-installation safety checks passed")
    }

    private func verifyDiskSpace(manifest _: UpdateManifest) async throws {
        log.info("Verifying disk space requirements")

        let currentAppSize = try calculateAppSize(Bundle.main.bundleURL)
        let requiredSpace = currentAppSize * 3 // Current app + backup + new app

        let availableSpace = try getAvailableDiskSpace()

        guard availableSpace > requiredSpace else {
            let errorMessage =
                "Insufficient disk space. Required: \(requiredSpace.formattedBytes), Available: \(availableSpace.formattedBytes)"
            log.error("\(errorMessage)")
            throw createSafetyError(errorMessage)
        }

        log.success("Disk space verification passed. Available: \(availableSpace.formattedBytes), Required: \(requiredSpace.formattedBytes)")
    }

    private func verifyCurrentAppIntegrity() async throws {
        try validateAppBundle(Bundle.main.bundleURL, isCurrentApp: true)
        log.success("Current application integrity verified")
    }

    private func verifyInstallationPermissions() async throws {
        log.info("Verifying installation permissions")

        let currentAppURL = Bundle.main.bundleURL
        let parentDirectory = currentAppURL.deletingLastPathComponent()

        // Check write permissions to parent directory
        guard fileManager.isWritableFile(atPath: parentDirectory.path) else {
            throw createSafetyError("No write permissions to application directory: \(parentDirectory.path)")
        }

        // Test by creating a temporary file
        let testFile = parentDirectory.appendingPathComponent("loop_permission_test_\(UUID().uuidString)")

        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFile)
        } catch {
            throw createSafetyError("Cannot write to application directory: \(error.localizedDescription)")
        }

        log.success("Installation permissions verified")
    }

    private func checkForConflictingRunningProcesses() async throws {
        log.info("Checking for interfering processes")

        // Check if any other updater processes are running
        let runningApps = NSWorkspace.shared.runningApplications
        let interferingApps = runningApps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return bundleId.contains("updater") || bundleId.contains("installer")
        }

        if !interferingApps.isEmpty {
            let appNames = interferingApps.compactMap(\.localizedName).joined(separator: ", ")
            log.warn("Found potentially interfering processes: \(appNames)")
        }

        log.success("Process interference check completed")
    }

    // MARK: - Download Verification

    private func verifyDownloadIntegrity(_ downloadURL: URL, manifest: UpdateManifest) async throws {
        try checkCancellation()
        log.info("Performing comprehensive download verification")

        // Basic file existence and readability
        guard fileManager.fileExists(atPath: downloadURL.path) else {
            throw createSafetyError("Download file does not exist: \(downloadURL.path)")
        }

        guard fileManager.isReadableFile(atPath: downloadURL.path) else {
            throw createSafetyError("Download file is not readable: \(downloadURL.path)")
        }

        // File size verification
        let attributes = try fileManager.attributesOfItem(atPath: downloadURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        guard fileSize > 0 else {
            throw createSafetyError("Download file is empty")
        }

        // Minimum reasonable size check (1KB)
        guard fileSize > 1024 else {
            throw createSafetyError("Download file is suspiciously small: \(fileSize) bytes")
        }

        log.info("Download file size: \(fileSize.formattedBytes)")

        // Checksum verification
        try await fileVerifier.verifyDownloadedFile(downloadURL, manifest: manifest)

        log.success("Download integrity verification completed")
    }

    // MARK: - Extraction with Verification

    private func extractAndVerifyUpdate(_ downloadURL: URL) async throws -> URL {
        try checkCancellation()
        log.info("Extracting update with comprehensive verification")

        let tempDir = createTemporaryExtractionDirectory()

        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Extract with safety checks
            try extractZipFile(downloadURL, to: tempDir)

            // Verify extraction completed successfully
            try await verifyExtractionCompleteness(tempDir)

            return tempDir
        } catch {
            // Clean up on failure
            try? fileManager.removeItem(at: tempDir)
            throw error
        }
    }

    private func extractZipFile(_ zipURL: URL, to destinationURL: URL) throws {
        try validateZipFile(zipURL)
        try performSafeZipExtraction(zipURL: zipURL, destinationURL: destinationURL)
    }

    private func performSafeZipExtraction(zipURL: URL, destinationURL: URL) throws {
        log.info("Extracting ZIP archive: \(zipURL.lastPathComponent)")

        guard let archive = try Archive(url: zipURL, accessMode: .read) else {
            throw createExtractionError("Could not open ZIP archive", code: -1, zipURL: zipURL)
        }

        for entry in archive where !entry.path.contains(/__MACOSX/) {
            try checkCancellation()
            _ = try archive.extract(entry, to: destinationURL.appendingPathComponent(entry.path))
        }

        log.success("Successfully extracted ZIP archive")
    }

    private func verifyExtractionCompleteness(_ extractedURL: URL) async throws {
        log.info("Verifying extraction completeness")

        // Check that we have at least one .app bundle
        let appBundle = try BundleUtilities.findAppBundle(in: extractedURL)

        // Verify the app bundle structure
        try BundleUtilities.verifyBundleStructure(appBundle)

        log.success("Extraction completeness verified")
    }

    // MARK: - Extraction Integrity Verification

    private func verifyExtractionIntegrity(_ extractedURL: URL, manifest: UpdateManifest) async throws {
        try checkCancellation()
        log.info("Performing extraction integrity verification")

        // Find and verify app bundle
        let appBundle = try BundleUtilities.findAppBundle(in: extractedURL)

        try await performPostExtractionSafetyChecks(appBundle, manifest: manifest)

        log.success("Extraction integrity verification completed")
    }

    private func performPostExtractionSafetyChecks(_ appBundle: URL, manifest: UpdateManifest) async throws {
        log.info("Performing additional extraction safety checks")

        // Comprehensive bundle validation
        try validateAppBundle(appBundle, manifest: manifest)

        // Code signature validation
        try await validateAppCodeSignature(appBundle)

        log.success("Additional extraction checks completed")
    }

    private func validateAppBundle(_ appBundle: URL, isCurrentApp: Bool = false, manifest: UpdateManifest? = nil) throws {
        log.info("Validating app bundle: \(appBundle.lastPathComponent)")

        // Check bundle structure
        try BundleUtilities.verifyBundleStructure(appBundle)

        // Check Info.plist
        let infoPlistURL = appBundle.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: infoPlistURL) else {
            throw createSafetyError("Could not read Info.plist")
        }

        // Validate basic bundle properties
        guard let bundleIdentifier = plist["CFBundleIdentifier"] as? String, !bundleIdentifier.isEmpty else {
            throw createSafetyError("Invalid CFBundleIdentifier")
        }

        guard let packageType = plist["CFBundlePackageType"] as? String, packageType == "APPL" else {
            throw createSafetyError("Invalid CFBundlePackageType")
        }

        // Validate executable
        guard let executableName = plist["CFBundleExecutable"] as? String, !executableName.isEmpty else {
            throw createSafetyError("Missing CFBundleExecutable")
        }

        let executablePath = appBundle.appendingPathComponent("Contents/MacOS/\(executableName)")
        guard fileManager.fileExists(atPath: executablePath.path) else {
            throw createSafetyError("Executable not found: \(executableName)")
        }

        let executableAttributes = try fileManager.attributesOfItem(atPath: executablePath.path)
        guard let permissions = executableAttributes[.posixPermissions] as? NSNumber,
              permissions.intValue & 0o111 != 0 else {
            throw createSafetyError("Executable lacks execute permissions")
        }

        // Version validation for extracted apps
        if !isCurrentApp, let manifest {
            try BundleVersionMatcher.verifyVersionMatches(bundleURL: appBundle, manifest: manifest)
        }

        // System compatibility check
        try validateSystemCompatibility(plist)

        log.success("App bundle validation completed")
    }

    private func validateSystemCompatibility(_ plist: NSDictionary) throws {
        // Check minimum OS version from plist
        if let minOSString = plist["LSMinimumSystemVersion"] as? String {
            let components = minOSString.split(separator: ".").compactMap { Int($0) }
            if components.count >= 2 {
                let minOSVersion = OperatingSystemVersion(
                    majorVersion: components[0],
                    minorVersion: components[1],
                    patchVersion: components.count > 2 ? components[2] : 0
                )

                guard ProcessInfo.processInfo.isOperatingSystemAtLeast(minOSVersion) else {
                    throw createSafetyError("App manifest inconsistency: app actually requires macOS \(minOSString) or later.")
                }
            }
        }

        // Check supported architectures
        if let supportedArchitectures = plist["LSArchitecturePriority"] as? [String] {
            guard supportedArchitectures.contains(SystemInfo.architecture) else {
                throw createSafetyError("App does not support current architecture")
            }
        }
    }

    private func validateAppCodeSignature(_ appBundle: URL) async throws {
        log.info("Validating app code signature")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--verbose", appBundle.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown codesign error"
            throw createSafetyError("Code signature validation failed: \(errorOutput)")
        }

        log.success("Code signature validation passed")
    }

    // MARK: - Safe Installation

    private func performSafeInstallation(from extractedURL: URL, manifest: UpdateManifest) async throws {
        try checkCancellation()
        log.info("Performing safe installation")

        // Pre-installation verification
        try await verifyPreInstallationState()

        // Perform atomic installation
        let appBundle = try BundleUtilities.findAppBundle(in: extractedURL)
        let currentAppURL = Bundle.main.bundleURL
        try await performAtomicInstallation(from: appBundle, to: currentAppURL, manifest: manifest)

        // Post-installation verification
        try await verifyPostInstallationState(manifest: manifest)

        log.success("Safe installation completed")
    }

    private func verifyPreInstallationState() async throws {
        log.info("Verifying pre-installation state")

        let currentAppURL = Bundle.main.bundleURL
        guard fileManager.fileExists(atPath: currentAppURL.path) else {
            throw createSafetyError("Current application no longer exists before installation")
        }

        try validateAppBundle(currentAppURL, isCurrentApp: true)
        log.success("Pre-installation state verified")
    }

    private func verifyPostInstallationState(manifest: UpdateManifest) async throws {
        log.info("Verifying post-installation state")

        let currentAppURL = Bundle.main.bundleURL
        guard fileManager.fileExists(atPath: currentAppURL.path) else {
            throw createSafetyError("Application missing after installation - CRITICAL ERROR")
        }

        try validateAppBundle(currentAppURL, isCurrentApp: true, manifest: manifest)
        log.success("Post-installation state verified")
    }

    // MARK: - Atomic Installation

    private func performAtomicInstallation(
        from sourceURL: URL,
        to destinationURL: URL,
        manifest: UpdateManifest
    ) async throws {
        log.info("Performing atomic installation")

        let stagingURL = destinationURL.appendingPathExtension("staging")

        do {
            try await executeAtomicInstallationSteps(
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

    private func executeAtomicInstallationSteps(
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

        try BundleUtilities.verifyBundleStructure(stagingURL)
        try BundleVersionMatcher.verifyVersionMatches(bundleURL: stagingURL, manifest: manifest)
        try await testStagedApplication(stagingURL)
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

    private func verifySwapSuccess(current: URL, backup: URL, staged: URL) throws {
        log.debug("Verifying atomic swap success...")

        // 1. Verify backup was created successfully
        guard fileManager.fileExists(atPath: backup.path) else {
            throw InstallationError.swapVerificationFailed("Backup not found at expected location: \(backup.path)")
        }

        // Verify backup has correct bundle structure
        try BundleUtilities.verifyBundleStructure(backup)
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
        try BundleUtilities.verifyBundleStructure(current)
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

    // MARK: - Comprehensive Verification

    private func performComprehensiveVerification(manifest: UpdateManifest) async throws {
        try checkCancellation()
        log.info("Performing comprehensive installation verification")

        // Standard verification
        try await verifyInstallation(manifest: manifest)

        // Additional comprehensive checks
        try await performFinalInstallationVerificationChecks(manifest: manifest)

        log.success("Comprehensive verification completed")
    }

    private func performFinalInstallationVerificationChecks(manifest _: UpdateManifest) async throws {
        log.info("Performing additional verification checks")

        let currentAppURL = Bundle.main.bundleURL

        // Verify app can be read
        guard fileManager.isReadableFile(atPath: currentAppURL.path) else {
            throw createSafetyError("Installed application is not readable")
        }

        // Comprehensive bundle validation
        try validateAppBundle(currentAppURL, isCurrentApp: true)

        log.success("Additional verification checks completed")
    }

    // MARK: - Pre-Restart Verification

    private func performPreRestartSafetyChecks() throws {
        log.info("Performing pre-restart verification")

        let currentAppURL = Bundle.main.bundleURL

        // Final check that app exists
        guard fileManager.fileExists(atPath: currentAppURL.path) else {
            throw createSafetyError("Application missing before restart")
        }

        // Final structure check
        try BundleUtilities.verifyBundleStructure(currentAppURL)

        // Check executable exists and has permissions
        guard let executablePath = Bundle.main.executablePath,
              fileManager.fileExists(atPath: executablePath) else {
            throw createSafetyError("Application executable missing before restart")
        }

        let attributes = try fileManager.attributesOfItem(atPath: executablePath)
        let permissions = attributes[.posixPermissions] as? NSNumber
        guard let permissions, permissions.intValue & 0o111 != 0 else {
            throw createSafetyError("Application executable lacks execute permissions before restart")
        }

        log.success("Pre-restart verification passed")
    }

    // MARK: - Enhanced Validation Methods

    private func validateZipFile(_ zipURL: URL) throws {
        log.info("Validating ZIP file: \(zipURL.path)")

        guard fileManager.fileExists(atPath: zipURL.path) else {
            throw createExtractionError("ZIP file not found", code: -3, zipURL: zipURL)
        }

        guard fileManager.isReadableFile(atPath: zipURL.path) else {
            throw createExtractionError("ZIP file is not readable", code: -4, zipURL: zipURL)
        }

        // Basic ZIP signature check
        let fileHandle = try FileHandle(forReadingFrom: zipURL)
        defer { fileHandle.closeFile() }

        let headerData = fileHandle.readData(ofLength: 4)
        guard headerData.count >= 2 else {
            throw createExtractionError("File is too small to be a valid ZIP archive", code: -6)
        }

        let (pk1, pk2) = (headerData[0], headerData[1])
        guard pk1 == 0x50, pk2 == 0x4B else {
            throw createExtractionError("File is not a valid ZIP archive (invalid signature)", code: -5)
        }

        log.success("ZIP file validation passed")
    }

    // MARK: - Standard Methods (Enhanced)

    private func verifyInstallation(manifest: UpdateManifest) async throws {
        try checkCancellation()

        log.info("Verifying installation success")
        try BundleVersionMatcher.verifyVersionMatches(bundleURL: Bundle.main.bundleURL, manifest: manifest)
        log.success("Installation verification completed successfully")
    }

    private func performSafeCleanup(_ extractedURL: URL, _ downloadURL: URL) async throws {
        log.info("Performing safe cleanup of temporary files")

        let cleanupOperations = [
            (extractedURL, "extraction directory"),
            (downloadURL, "download file")
        ]

        for (url, description) in cleanupOperations {
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                    log.debug("Removed \(description): \(url.path)")
                } catch {
                    log.warn("Failed to clean up \(description): \(error)")
                    // Don't fail installation for cleanup issues
                }
            }
        }

        log.success("Safe cleanup completed")
    }

    // MARK: - Utility Methods

    private func checkCancellation() throws {
        guard !isCancelled else {
            throw UpdateError.installationError("Installation cancelled")
        }
    }

    private func fallbackApplicationRestart(appPath: String) {
        log.info("Attempting fallback application restart")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [appPath]

        do {
            try task.run()
            log.success("Application restart initiated via fallback method")
        } catch {
            log.error("Failed to restart application via fallback: \(error)")
        }
    }

    private func createTemporaryExtractionDirectory() -> URL {
        fileManager.temporaryDirectory.appendingPathComponent("LoopExtraction_\(UUID().uuidString)")
    }

    private func calculateAppSize(_ appURL: URL) throws -> Int64 {
        var totalSize: Int64 = 0

        let enumerator = fileManager.enumerator(
            at: appURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += Int64(resourceValues.fileSize ?? 0)
        }

        return totalSize
    }

    private func getAvailableDiskSpace() throws -> Int64 {
        let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
        return attributes[.systemFreeSize] as? Int64 ?? 0
    }

    private func createSafetyError(_ message: String) -> UpdateError {
        .installationError(message)
    }

    private func createExtractionError(_ message: String, code _: Int, zipURL: URL? = nil) -> UpdateError {
        var fullMessage = message
        if let zipURL {
            let fileSize = try? fileManager.attributesOfItem(atPath: zipURL.path)[.size] as? Int64
            let fileSizeString = fileSize?.formattedBytes ?? "unknown size"
            fullMessage = "\(message) at \(zipURL.path) (Size: \(fileSizeString))"
        }

        return .installationError(fullMessage)
    }
}

// MARK: - InstallationState

private enum InstallationState {
    case idle, inProgress, completed, failed, cancelled
}
