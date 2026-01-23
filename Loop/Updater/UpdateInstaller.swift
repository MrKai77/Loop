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

@Loggable
actor UpdateInstaller {
    // MARK: - Types

    typealias ProgressHandler = @Sendable (UpdateProgress) -> ()

    // MARK: - Properties

    private let config: UpdaterConfig
    private let fileVerifier: FileVerifier
    private let coordinator: InstallationCoordinator
    private let fileManager: FileManager

    private var isCancelled = false
    private var installationState: InstallationState = .idle

    init(config: UpdaterConfig, fileManager: FileManager = .default) {
        self.config = config
        self.fileManager = fileManager
        self.fileVerifier = FileVerifier(config: config)
        self.coordinator = InstallationCoordinator(config: config, fileManager: fileManager)
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

    func cancel() {
        log.warn("Cancelling installation")
        isCancelled = true
        installationState = .cancelled
        coordinator.cancel()
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
            ("system requirements", { try self.verifySystemRequirements(manifest: manifest) }),
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

    private func verifySystemRequirements(manifest: UpdateManifest) throws {
        log.info("Verifying system requirements")

        let currentOS = ProcessInfo.processInfo.operatingSystemVersion
        let minimumOS = manifest.minimumOS

        // Parse minimum OS version (assuming format like "13.0")
        let components = minimumOS.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 2 else {
            log.warn("Could not parse minimum OS version: \(minimumOS)")
            return
        }

        let requiredMajor = components[0]
        let requiredMinor = components[1]

        if currentOS.majorVersion < requiredMajor ||
            (currentOS.majorVersion == requiredMajor && currentOS.minorVersion < requiredMinor) {
            let currentOSString = "\(currentOS.majorVersion).\(currentOS.minorVersion).\(currentOS.patchVersion)"
            throw createSafetyError(
                "System does not meet minimum OS requirement. Current: \(currentOSString), Required: \(minimumOS)"
            )
        }

        log.success("System requirements verified")
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

        for entry in archive {
            try checkCancellation()
            _ = try archive.extract(entry, to: destinationURL.appendingPathComponent(entry.path))
        }

        log.success("Successfully extracted ZIP archive")
    }

    private func verifyExtractionCompleteness(_ extractedURL: URL) async throws {
        log.info("Verifying extraction completeness")

        // Check that we have at least one .app bundle
        let appBundle = try findAppBundle(in: extractedURL)

        // Verify the app bundle structure
        try verifyAppBundleStructureAndContents(appBundle)

        // Check that essential files exist
        let requiredFiles = [
            "Contents/Info.plist",
            "Contents/MacOS"
        ]

        for requiredFile in requiredFiles {
            let filePath = appBundle.appendingPathComponent(requiredFile)
            guard fileManager.fileExists(atPath: filePath.path) else {
                throw createSafetyError("Missing required file after extraction: \(requiredFile)")
            }
        }

        log.success("Extraction completeness verified")
    }

    // MARK: - Extraction Integrity Verification

    private func verifyExtractionIntegrity(_ extractedURL: URL, manifest: UpdateManifest) async throws {
        try checkCancellation()
        log.info("Performing extraction integrity verification")

        // Find and verify app bundle
        let appBundle = try findAppBundle(in: extractedURL)

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
        try verifyAppBundleStructureAndContents(appBundle)

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
            try validateAppVersion(plist, manifest: manifest)
        }

        // System compatibility check
        try validateSystemCompatibility(plist, manifest: manifest)

        log.success("App bundle validation completed")
    }

    private func validateAppVersion(_ plist: NSDictionary, manifest: UpdateManifest) throws {
        guard let version = plist["CFBundleShortVersionString"] as? String,
              let buildString = plist["CFBundleVersion"] as? String,
              let build = Int(buildString) else {
            throw createSafetyError("Invalid version information in app's Info.plist")
        }

        let normalizedAppVersion = version.replacingOccurrences(of: "🧪 ", with: "")
        let normalizedManifestVersion = manifest.version.replacingOccurrences(of: "🧪 ", with: "")

        guard normalizedAppVersion == normalizedManifestVersion, build == manifest.buildNumber else {
            throw createSafetyError(
                "Version mismatch. Expected: \(manifest.version)(\(manifest.buildNumber)), Got: \(version)(\(build))"
            )
        }
    }

    private func validateSystemCompatibility(_ plist: NSDictionary, manifest: UpdateManifest?) throws {
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
                    throw createSafetyError("App requires macOS \(minOSString) or later")
                }
            }
        }

        // Check supported architectures
        if let supportedArchitectures = plist["LSArchitecturePriority"] as? [String] {
            guard supportedArchitectures.contains(SystemInfo.architecture) else {
                throw createSafetyError("App does not support current architecture")
            }
        }

        // Check against manifest requirements
        if let manifest {
            let components = manifest.minimumOS.split(separator: ".").compactMap { Int($0) }
            if components.count >= 2 {
                let manifestMinVersion = OperatingSystemVersion(
                    majorVersion: components[0],
                    minorVersion: components[1],
                    patchVersion: components.count > 2 ? components[2] : 0
                )

                guard ProcessInfo.processInfo.isOperatingSystemAtLeast(manifestMinVersion) else {
                    throw createSafetyError("Update requires macOS \(manifest.minimumOS) or later")
                }
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

        // Perform installation with coordinator
        try await coordinator.performInstallation(from: extractedURL, manifest: manifest)

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
        try verifyAppBundleStructureAndContents(currentAppURL)

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
        log.info("Expected version: \(manifest.version)")
        log.info("Expected build: \(manifest.buildNumber)")

        let installedVersion = try getInstalledVersion()
        log.info("Currently installed version: \(installedVersion)")

        // Extract version components for comparison (format: "🧪 1.4.1 (1683)" or "1.4.1 (1683)")
        let versionComponents = installedVersion.split(separator: " ")
        guard versionComponents.count >= 1 else {
            let errorMessage = "Invalid installed version format: \(installedVersion)"
            log.error("Version format error: \(errorMessage)")
            throw UpdateError.installationError(errorMessage)
        }

        // Handle emoji prefix - if present, version starts at index 1, otherwise at index 0
        let versionStartIndex = versionComponents[0].hasPrefix("🧪") ? 1 : 0
        let installedVersionOnly = String(versionComponents[versionStartIndex])
        let installedBuildOnly = versionComponents.count > versionStartIndex + 1 ?
            String(versionComponents[versionStartIndex + 1].replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")) : "0"
        let installedBuildInt = Int(installedBuildOnly) ?? 0

        // Compare version and build separately
        guard installedVersionOnly == manifest.version, installedBuildInt == manifest.buildNumber else {
            let errorMessage = "Installed version \(installedVersionOnly) (\(installedBuildInt)) doesn't match expected \(manifest.version) (\(manifest.buildNumber))"
            log.error("Version mismatch: installed=\(installedVersionOnly) (\(installedBuildInt)), expected=\(manifest.version) (\(manifest.buildNumber))")
            throw UpdateError.installationError(errorMessage)
        }

        log.success("Installation verification completed successfully")
    }

    private func getInstalledVersion() throws -> String {
        let bundleURL = Bundle.main.bundleURL

        guard let (version, build) = readVersionInfo(from: bundleURL) else {
            throw UpdateError.installationError("Could not read version from installed application")
        }

        return "\(version) (\(build))"
    }

    private func readVersionInfo(from bundleURL: URL) -> (version: String, build: Int)? {
        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")

        guard let plist = NSDictionary(contentsOf: infoPlistURL),
              let version = plist["CFBundleShortVersionString"] as? String,
              let buildString = plist["CFBundleVersion"] as? String,
              let build = Int(buildString) else {
            return nil
        }

        return (version, build)
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

    private func verifyAppBundleStructureAndContents(_ bundleURL: URL) throws {
        log.debug("Verifying bundle structure for: \(bundleURL.lastPathComponent)")

        let requiredPaths = AppBundleConstants.requiredPaths

        for path in requiredPaths {
            let fullPath = bundleURL.appendingPathComponent(path)
            guard fileManager.fileExists(atPath: fullPath.path) else {
                log.error("Missing required path: \(path)")
                throw createSafetyError("Invalid app bundle: missing \(path)")
            }
        }

        log.debug("Bundle structure verification passed")
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

// MARK: - Constants

private enum AppBundleConstants {
    static let requiredPaths = ["Contents/Info.plist", "Contents/MacOS"]
}

// MARK: - InstallationState

private enum InstallationState {
    case idle, inProgress, completed, failed, cancelled
}
