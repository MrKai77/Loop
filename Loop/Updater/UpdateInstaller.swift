//
//  UpdateInstaller.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import AppKit
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
actor UpdateInstaller {
    // MARK: - Types

    typealias ProgressHandler = @Sendable (UpdateProgress) -> ()

    // MARK: - Properties

    private let config: UpdaterConfig
    private let fileVerifier: FileVerifier
    private let backupManager: BackupManager
    private let fileManager: FileManager

    private var isCancelled = false
    private var installationState: InstallationState = .idle
    private var relocateToApplications = false

    init(config: UpdaterConfig, fileManager: FileManager = .default) {
        self.config = config
        self.fileManager = fileManager
        self.fileVerifier = FileVerifier(config: config)
        self.backupManager = BackupManager(fileManager: fileManager)
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

        // Check location and offer relocation if needed
        try await checkAppLocationAndOfferRelocation()

        log.success("All pre-installation safety checks passed")
    }

    private func checkAppLocationAndOfferRelocation() async throws {
        let location = AppLocation.current

        switch location {
        case .systemApplications, .userApplications:
            log.info("App is in Applications folder: \(location)")
            relocateToApplications = false
        case let .other(path):
            log.warn("App is not in Applications folder: \(path)")

            let shouldRelocate = await askUserForRelocation()

            if shouldRelocate {
                log.info("User chose to install to Applications folder")
                relocateToApplications = true
            } else {
                log.info("User chose to keep current location. Update will install to: \(path)")
                relocateToApplications = false
            }
        }
    }

    @MainActor
    private func askUserForRelocation() async -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "Move to Applications Folder?")
        alert.informativeText = String(localized: "Loop is not in your Applications folder. Would you like to install the update to your Applications folder instead?")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "Install to Applications"))
        alert.addButton(withTitle: String(localized: "Keep in Current Location"))
        return alert.runModal() == .alertFirstButtonReturn
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

    // MARK: - Extraction

    private func extractAndVerifyUpdate(_ downloadURL: URL) async throws -> URL {
        try checkCancellation()
        return try ZipExtractor.extract(from: downloadURL, cancellationCheck: checkCancellation)
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
            try BundleUtilities.verifyVersionMatches(bundleURL: appBundle, manifest: manifest)
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

        let appBundle = try BundleUtilities.findAppBundle(in: extractedURL)

        if relocateToApplications {
            try await performRelocationInstall(from: appBundle, manifest: manifest)
        } else {
            // Pre-installation verification
            try await verifyPreInstallationState()

            // Perform atomic installation to current location
            let currentAppURL = Bundle.main.bundleURL
            try await performAtomicInstallation(from: appBundle, to: currentAppURL, manifest: manifest)

            // Post-installation verification
            try await verifyPostInstallationState(manifest: manifest)
        }

        log.success("Safe installation completed")
    }

    private func performRelocationInstall(from appBundle: URL, manifest: UpdateManifest) async throws {
        log.info("Installing to Applications folder")

        let userAppsURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        let destinationURL = userAppsURL.appendingPathComponent("Loop.app")

        // Create ~/Applications if needed
        try fileManager.createDirectory(at: userAppsURL, withIntermediateDirectories: true)

        // Remove existing app at destination if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            log.info("Removing existing app at destination: \(destinationURL.path)")
            try fileManager.removeItem(at: destinationURL)
        }

        // Copy new app to Applications
        log.info("Copying new version to: \(destinationURL.path)")
        try fileManager.copyItem(at: appBundle, to: destinationURL)

        // Verify the installation
        try BundleUtilities.verifyBundleStructure(destinationURL)
        try BundleUtilities.verifyVersionMatches(bundleURL: destinationURL, manifest: manifest)

        // Remove old app from original location
        let oldAppURL = Bundle.main.bundleURL
        log.info("Removing old app from: \(oldAppURL.path)")
        do {
            try fileManager.removeItem(at: oldAppURL)
        } catch {
            log.warn("Could not remove old app (non-fatal): \(error.localizedDescription)")
        }

        log.success("Successfully installed to Applications folder")

        // Launch from new location and quit current instance
        try await launchAndTerminate(appURL: destinationURL)
    }

    private func launchAndTerminate(appURL: URL) async throws {
        log.info("Launching app from: \(appURL.path)")

        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)

        // Give the new instance time to start
        try await Task.sleep(for: .seconds(1))

        // Terminate current instance
        log.info("Terminating current instance")
        await MainActor.run {
            NSApplication.shared.terminate(nil)
        }
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
        try BundleUtilities.verifyVersionMatches(bundleURL: stagingURL, manifest: manifest)
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

        try await backupManager.prepareForBackup()
        let backupURL = try await backupManager.createBackupURL()

        try await performSwapOperation(
            current: currentURL,
            staged: stagingURL,
            backup: backupURL
        )
    }

    private func performSwapOperation(current: URL, staged: URL, backup: URL) async throws {
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
            log.success("Atomic swap completed and verified successfully!")
        } catch {
            log.error("Atomic swap failed: \(error)")
            log.error("Current: \(current.path), Staged: \(staged.path), Backup: \(backup.path)")
            log.error("Current exists: \(fileManager.fileExists(atPath: current.path))")
            log.error("Staged exists: \(fileManager.fileExists(atPath: staged.path))")
            log.error("Backup exists: \(fileManager.fileExists(atPath: backup.path))")

            try await backupManager.restoreFromBackup(currentURL: current, backupURL: backup)
            throw error
        }
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
        log.debug("Atomic swap verification completed")
    }

    private func cleanupStaging(_ stagingURL: URL) async {
        try? fileManager.removeItem(at: stagingURL)
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

    // MARK: - Standard Methods

    private func verifyInstallation(manifest: UpdateManifest) async throws {
        try checkCancellation()

        log.info("Verifying installation success")
        try BundleUtilities.verifyVersionMatches(bundleURL: Bundle.main.bundleURL, manifest: manifest)
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
}

// MARK: - InstallationState

private enum InstallationState {
    case idle, inProgress, completed, failed, cancelled
}

// MARK: - AppLocation

enum AppLocation: CustomStringConvertible, Sendable {
    case systemApplications
    case userApplications
    case other(String)

    static var current: AppLocation {
        let bundlePath = Bundle.main.bundlePath
        let userAppsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        let systemAppsPath = "/Applications"

        if bundlePath.hasPrefix(systemAppsPath) {
            return .systemApplications
        } else if bundlePath.hasPrefix(userAppsPath) {
            return .userApplications
        } else {
            return .other(bundlePath)
        }
    }

    var description: String {
        switch self {
        case .systemApplications: "/Applications"
        case .userApplications: "~/Applications"
        case let .other(path): path
        }
    }

    var isInApplicationsFolder: Bool {
        switch self {
        case .systemApplications, .userApplications: true
        case .other: false
        }
    }
}
