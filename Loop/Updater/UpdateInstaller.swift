//
//  UpdateInstaller.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import AppKit
import Foundation
import Scribe

@Loggable
actor UpdateInstaller {
    // MARK: - Properties

    private let backupManager: BackupManager
    private let fileManager: FileManager

    private var isCancelled = false
    private var relocateToApplications = false
    private var installedAppURL: URL = Bundle.main.bundleURL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.backupManager = BackupManager(fileManager: fileManager)
    }

    func installUpdate(
        from downloadURL: URL,
        manifest: UpdateManifest,
        progress: @escaping (UpdateProgress) async -> ()
    ) async throws {
        log.info("Starting installation of update: \(manifest.version)")

        // Step 1: Pre-installation verification
        try await performPreInstallationChecks(manifest: manifest)
        await progress(UpdateProgress(phase: .checking, percentage: 1.0 / 8.0))

        // Step 2: Verify download integrity
        try await verifyDownloadIntegrity(downloadURL, manifest: manifest)
        await progress(UpdateProgress(phase: .downloading, percentage: 2.0 / 8.0))

        // Step 3: Extract and verify
        let extractedURL = try await extract(downloadURL)
        await progress(UpdateProgress(phase: .extracting, percentage: 3.0 / 8.0))

        // Step 4: Verify extraction integrity
        try await verifyExtractionIntegrity(extractedURL, manifest: manifest)
        await progress(UpdateProgress(phase: .verifying, percentage: 4.0 / 8.0))

        // Step 5: Perform safe installation
        try await performSafeInstallation(from: extractedURL, manifest: manifest)
        await progress(UpdateProgress(phase: .installing, percentage: 5.0 / 8.0))

        // Step 6: Comprehensive verification
        try await performFinalVerification(manifest: manifest)
        await progress(UpdateProgress(phase: .verifying, percentage: 6.0 / 8.0))

        // Step 7: Cleanup
        try await performSafeCleanup(extractedURL, downloadURL)
        await progress(UpdateProgress(phase: .cleaning, percentage: 7.0 / 8.0))

        try performPreRestartSafetyChecks()
        await progress(UpdateProgress(phase: .verifying, percentage: 8.0 / 8.0))

        log.success("Installation completed successfully")
    }

    func restartApplication() async {
        log.info("Preparing application restart from: \(installedAppURL.path)")

        // Verify the app exists before attempting restart
        guard fileManager.fileExists(atPath: installedAppURL.path) else {
            log.error("Application not found at path before restart: \(installedAppURL.path)")
            return
        }

        log.notice("Application will now restart. New instance will launch in 0.5 seconds.")

        let appURL = installedAppURL
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", "sleep 0.5; open \"\(appURL.path)\""]
        process.launch()

        await MainActor.run {
            NSApp.terminate(nil)
        }
    }

    func cancel() async {
        log.warn("Cancelling installation")
        isCancelled = true
    }

    // MARK: - Pre-Installation Safety Checks

    private func performPreInstallationChecks(manifest: UpdateManifest) async throws {
        log.info("Performing pre-installation safety checks")

        try checkCancellation()

        let checks: [(String, () async throws -> ())] = [
            ("disk space", { try await self.verifyDiskSpace(manifest: manifest) }),
            ("current app integrity", { try await self.verifyCurrentAppIntegrity() }),
            ("installation permissions", { try await self.verifyInstallationPermissions() }),
            ("conflicting processes", { try await self.checkForConflictingRunningProcesses() }),
            ("app location", { try await self.checkAppLocationAndOfferRelocation() })
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
        alert.informativeText = String(localized: "\(Bundle.main.appName) is not in your Applications folder. Would you like to install the update to your Applications folder instead?")
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
            throw UpdateError.installationFailed(errorMessage)
        }

        log.success("Disk space verification passed. Available: \(availableSpace.formattedBytes), Required: \(requiredSpace.formattedBytes)")
    }

    private func verifyCurrentAppIntegrity() async throws {
        try validateAppBundle(Bundle.main.bundleURL, skipVersionCheck: true)
        log.success("Current application integrity verified")
    }

    private func verifyInstallationPermissions() async throws {
        log.info("Verifying installation permissions")

        let currentAppURL = Bundle.main.bundleURL
        let parentDirectory = currentAppURL.deletingLastPathComponent()

        // Check write permissions to parent directory
        guard fileManager.isWritableFile(atPath: parentDirectory.path) else {
            throw UpdateError.installationFailed("No write permissions to application directory: \(parentDirectory.path)")
        }

        // Test by creating a temporary file
        let testFile = parentDirectory.appendingPathComponent("loop_permission_test_\(UUID().uuidString)")

        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFile)
        } catch {
            throw UpdateError.installationFailed("Cannot write to application directory: \(error.localizedDescription)")
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
            throw UpdateError.installationFailed("Download file does not exist: \(downloadURL.path)")
        }

        guard fileManager.isReadableFile(atPath: downloadURL.path) else {
            throw UpdateError.installationFailed("Download file is not readable: \(downloadURL.path)")
        }

        // File size verification
        let attributes = try fileManager.attributesOfItem(atPath: downloadURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        guard fileSize > 0 else {
            throw UpdateError.installationFailed("Download file is empty")
        }

        // Minimum reasonable size check (1KB)
        guard fileSize > 1024 else {
            throw UpdateError.installationFailed("Download file is suspiciously small: \(fileSize) bytes")
        }

        log.info("Download file size: \(fileSize.formattedBytes)")

        // Checksum verification
        try await ChecksumVerifier.verifyFile(
            downloadURL,
            expectedChecksum: manifest.checksums.zip
        )

        log.success("Download integrity verification completed")
    }

    // MARK: - Extraction

    private func extract(_ downloadURL: URL) async throws -> URL {
        try checkCancellation()
        return try ZipExtractor.extract(from: downloadURL, cancellationCheck: checkCancellation)
    }

    // MARK: - Extraction Integrity Verification

    private func verifyExtractionIntegrity(_ extractedURL: URL, manifest: UpdateManifest) async throws {
        try checkCancellation()
        log.info("Performing extraction integrity verification")

        // Find and verify app bundle
        let appBundle = try BundleUtilities.findAppBundle(in: extractedURL)

        // Comprehensive bundle validation
        try validateAppBundle(appBundle, manifest: manifest)

        // Code signature validation
        try await validateAppCodeSignature(appBundle)

        log.success("Extraction integrity verification completed")
    }

    private func validateAppBundle(_ appBundle: URL, skipVersionCheck: Bool = false, manifest: UpdateManifest? = nil) throws {
        log.info("Validating app bundle: \(appBundle.lastPathComponent)")

        // Check bundle structure
        try BundleUtilities.verifyBundleStructure(appBundle)

        // Check Info.plist
        let infoPlistURL = appBundle.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: infoPlistURL) else {
            throw UpdateError.installationFailed("Could not read Info.plist")
        }

        // Validate basic bundle properties
        guard let bundleIdentifier = plist["CFBundleIdentifier"] as? String, !bundleIdentifier.isEmpty else {
            throw UpdateError.installationFailed("Invalid CFBundleIdentifier")
        }

        guard let packageType = plist["CFBundlePackageType"] as? String, packageType == "APPL" else {
            throw UpdateError.installationFailed("Invalid CFBundlePackageType")
        }

        // Validate executable
        guard let executableName = plist["CFBundleExecutable"] as? String, !executableName.isEmpty else {
            throw UpdateError.installationFailed("Missing CFBundleExecutable")
        }

        let executablePath = appBundle.appendingPathComponent("Contents/MacOS/\(executableName)")
        guard fileManager.fileExists(atPath: executablePath.path) else {
            throw UpdateError.installationFailed("Executable not found: \(executableName)")
        }

        let executableAttributes = try fileManager.attributesOfItem(atPath: executablePath.path)
        guard let permissions = executableAttributes[.posixPermissions] as? NSNumber,
              permissions.intValue & 0o111 != 0 else {
            throw UpdateError.installationFailed("Executable lacks execute permissions")
        }

        // Version validation for extracted apps
        if !skipVersionCheck, let manifest {
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
                    throw UpdateError.installationFailed("App manifest inconsistency: app actually requires macOS \(minOSString) or later.")
                }
            }
        }

        // Check supported architectures – plist value is an array of strings
        if let archStrings = plist["LSArchitecturePriority"] as? [String] {
            // Map string representations to our internal Architecture enum
            let supportedArchitectures: [SystemInfo.Architecture] = archStrings.compactMap { arch in
                switch arch.lowercased() {
                case "arm64": .arm64
                case "x86_64", "x86-64", "x86": .x86_64
                default: nil
                }
            }

            guard !supportedArchitectures.isEmpty else {
                // No recognized architectures, assume compatible
                return
            }

            guard supportedArchitectures.contains(SystemInfo.architecture) else {
                throw UpdateError.installationFailed("App does not support current architecture")
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
            throw UpdateError.installationFailed("Code signature validation failed: \(errorOutput)")
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
            // Pre-installation verification (checks current running app)
            try await verifyPreInstallationState()

            // Perform atomic installation to current location
            let currentAppURL = Bundle.main.bundleURL
            try await performAtomicInstallation(from: appBundle, to: currentAppURL, manifest: manifest)
        }

        // Post-installation verification
        try await verifyPostInstallationState(manifest: manifest)

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

        // Store the new location for restart
        installedAppURL = destinationURL

        // Remove old app from original location
        let oldAppURL = Bundle.main.bundleURL
        log.info("Removing old app from: \(oldAppURL.path)")
        do {
            try fileManager.removeItem(at: oldAppURL)
        } catch {
            log.warn("Could not remove old app: \(error.localizedDescription)")
        }

        log.success("Successfully installed to Applications folder")
    }

    private func verifyPreInstallationState() async throws {
        log.info("Verifying pre-installation state")

        let currentAppURL = Bundle.main.bundleURL
        guard fileManager.fileExists(atPath: currentAppURL.path) else {
            throw UpdateError.installationFailed("Current application no longer exists before installation")
        }

        try validateAppBundle(currentAppURL, skipVersionCheck: true)
        log.success("Pre-installation state verified")
    }

    private func verifyPostInstallationState(manifest: UpdateManifest) async throws {
        log.info("Verifying post-installation state")

        guard fileManager.fileExists(atPath: installedAppURL.path) else {
            throw UpdateError.installationFailed("Application missing after installation - CRITICAL ERROR")
        }

        try validateAppBundle(installedAppURL, manifest: manifest)
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
            throw UpdateError.installationFailed("No executable found in app bundle")
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
            throw UpdateError.installationFailed("Atomic swap verification failed: Backup not found at expected location: \(backup.path)")
        }

        // Verify backup has correct bundle structure
        try BundleUtilities.verifyBundleStructure(backup)
        log.debug("Backup bundle structure verified")

        // Verify backup has a valid Info.plist and version
        let backupInfoPlistURL = backup.appendingPathComponent("Contents/Info.plist")
        guard fileManager.fileExists(atPath: backupInfoPlistURL.path) else {
            throw UpdateError.installationFailed("Atomic swap verification failed: Backup app Info.plist not found")
        }

        guard let backupPlist = NSDictionary(contentsOf: backupInfoPlistURL),
              let backupVersion = backupPlist["CFBundleShortVersionString"] as? String,
              !backupVersion.isEmpty else {
            throw UpdateError.installationFailed("Atomic swap verification failed: Backup app version information is invalid")
        }

        log.debug("Backup version verified: \(backupVersion)")

        // 2. Verify new app was installed successfully
        guard fileManager.fileExists(atPath: current.path) else {
            throw UpdateError.installationFailed("Atomic swap verification failed: New app not found at expected location: \(current.path)")
        }

        // Verify new app has correct bundle structure
        try BundleUtilities.verifyBundleStructure(current)
        log.debug("New app bundle structure verified")

        // Verify new app has a valid Info.plist and version
        let infoPlistURL = current.appendingPathComponent("Contents/Info.plist")
        guard fileManager.fileExists(atPath: infoPlistURL.path) else {
            throw UpdateError.installationFailed("Atomic swap verification failed: New app Info.plist not found")
        }

        guard let plist = NSDictionary(contentsOf: infoPlistURL),
              let version = plist["CFBundleShortVersionString"] as? String,
              !version.isEmpty else {
            throw UpdateError.installationFailed("Atomic swap verification failed: New app version information is invalid")
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
            throw UpdateError.installationFailed("Atomic swap verification failed: Backup appears to be empty or invalid")
        }

        guard let currentSize = currentAttributes[.size] as? Int64, currentSize > 0 else {
            throw UpdateError.installationFailed("Atomic swap verification failed: New app appears to be empty or invalid")
        }

        log.debug("File sizes verified - Backup: \(backupSize.formattedBytes), New: \(currentSize.formattedBytes)")
        log.debug("Atomic swap verification completed")
    }

    private func cleanupStaging(_ stagingURL: URL) async {
        try? fileManager.removeItem(at: stagingURL)
    }

    // MARK: - Final Verification

    private func performFinalVerification(manifest: UpdateManifest) async throws {
        try checkCancellation()
        log.info("Performing comprehensive installation verification")

        // Verify app can be read
        guard fileManager.isReadableFile(atPath: installedAppURL.path) else {
            throw UpdateError.installationFailed("Installed application is not readable")
        }

        // Comprehensive bundle validation
        try validateAppBundle(installedAppURL, manifest: manifest)

        log.success("Comprehensive verification completed")
    }

    // MARK: - Pre-Restart Verification

    private func performPreRestartSafetyChecks() throws {
        log.info("Performing pre-restart verification")

        // Final check that app exists
        guard fileManager.fileExists(atPath: installedAppURL.path) else {
            throw UpdateError.installationFailed("Application missing before restart")
        }

        // Final structure check
        try BundleUtilities.verifyBundleStructure(installedAppURL)

        // Check executable exists and has permissions
        let executablePath = try BundleUtilities.executablePath(for: installedAppURL)
        guard fileManager.fileExists(atPath: executablePath.path) else {
            throw UpdateError.installationFailed("Application executable missing before restart")
        }

        let attributes = try fileManager.attributesOfItem(atPath: executablePath.path)
        let permissions = attributes[.posixPermissions] as? NSNumber
        guard let permissions, permissions.intValue & 0o111 != 0 else {
            throw UpdateError.installationFailed("Application executable lacks execute permissions before restart")
        }

        log.success("Pre-restart verification passed")
    }

    // MARK: - Standard Methods

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
            throw UpdateError.installationFailed("Installation cancelled")
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
}
