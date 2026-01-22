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

@Loggable(style: .static)
public class UpdateInstaller: @unchecked Sendable {
    // MARK: - Types

    public typealias ProgressHandler = @Sendable (UpdateProgress) -> ()

    // MARK: - Properties

    private let config: UpdaterConfig
    private let fileVerifier: FileVerifier
    private let coordinator: InstallationCoordinator
    private let fileManager: FileManager

    private var isCancelled = false
    private var installationState: InstallationState = .idle

    private static let extractionQueue: DispatchQueue = .init(label: "com.loop.extraction", qos: .userInitiated)
    private static let verificationQueue: DispatchQueue = .init(
        label: "com.loop.verification",
        qos: .userInitiated
    )
    private static let installationSteps: InstallationSteps = .init()

    public init(config: UpdaterConfig, fileManager: FileManager = .default) {
        self.config = config
        self.fileManager = fileManager
        self.fileVerifier = FileVerifier(config: config)
        self.coordinator = InstallationCoordinator(config: config, fileManager: fileManager)
    }

    public func installUpdate(from downloadURL: URL, manifest: UpdateManifest) async throws {
        Log.info("Starting installation of update: \(manifest.version)")

        // Pre-installation safety checks
        try await performPreInstallationChecks(manifest: manifest)

        do {
            installationState = .inProgress
            try await executeInstallationSequence(downloadURL: downloadURL, manifest: manifest)
            installationState = .completed
            Log.success("Installation completed successfully")
        } catch {
            installationState = .failed
            Log.error("Installation failed: \(error)")
            throw UpdateError.installationFailed(error)
        }
    }

    public func installUpdateWithProgress(
        from downloadURL: URL,
        manifest: UpdateManifest,
        progressHandler: ProgressHandler? = nil
    ) async throws {
        Log.info("Starting installation with progress tracking")

        try await performPreInstallationChecks(manifest: manifest)

        let steps = Self.installationSteps
        var extractedURL: URL?

        do {
            installationState = .inProgress

            for step in steps.all {
                try checkCancellation()
                progressHandler?(UpdateProgress(phase: step.phase, percentage: step.progress))

                switch step.type {
                case .preCheck:
                    try await performPreInstallationChecks(manifest: manifest)
                case .verifyDownload:
                    try await verifyDownloadIntegrity(downloadURL, manifest: manifest)
                case .extract:
                    extractedURL = try await extractAndVerifyUpdate(downloadURL)
                case .verifyExtraction:
                    guard let url = extractedURL else { throw createSafetyError("No extracted URL available") }
                    try await verifyExtractionIntegrity(url, manifest: manifest)
                case .install:
                    guard let url = extractedURL else { throw createSafetyError("No extracted URL available") }
                    try await performSafeInstallation(from: url, manifest: manifest)
                case .verify:
                    try await performComprehensiveVerification(manifest: manifest)
                case .cleanup:
                    if let url = extractedURL {
                        try await performSafeCleanup(url, downloadURL)
                    }
                }
            }

            installationState = .completed
            progressHandler?(UpdateProgress(phase: .completed, percentage: 1.0))
            Log.success("Installation with progress completed successfully")

        } catch {
            installationState = .failed
            Log.error("Installation failed during step: \(error)")

            if let url = extractedURL {
                try await performSafeCleanup(url, downloadURL)
            }

            throw UpdateError.installationFailed(error)
        }
    }

    public func restartApplication() {
        Log.info("Preparing application restart")

        // Final verification before restart
        do {
            try performPreRestartSafetyChecks()
        } catch {
            Log.error("Pre-restart verification failed: \(error)")
            // Don't restart if verification fails
            return
        }

        let appURL = URL(fileURLWithPath: Bundle.main.bundlePath)

        // Verify the app exists before attempting restart
        guard fileManager.fileExists(atPath: appURL.path) else {
            Log.error("Application not found at path before restart: \(appURL.path)")
            return
        }

        Log.info("Pre-restart verification passed, proceeding with restart")

        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            self.attemptApplicationRestart(appURL: appURL)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }

    public func cancel() {
        Log.warn("Cancelling installation")
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
        Log.info("Performing pre-installation safety checks")

        try checkCancellation()

        // Check disk space
        try await verifyDiskSpace(manifest: manifest)

        // Check current app integrity
        try await verifyCurrentAppIntegrity()

        // Check permissions
        try await verifyInstallationPermissions()

        // Check system requirements
        try verifySystemRequirements(manifest: manifest)

        // Check for running processes that might interfere
        try await checkForConflictingRunningProcesses()

        Log.success("All pre-installation safety checks passed")
    }

    private func verifyDiskSpace(manifest _: UpdateManifest) async throws {
        Log.info("Verifying disk space requirements")

        let currentAppSize = try calculateAppSize(Bundle.main.bundleURL)
        let requiredSpace = currentAppSize * 3 // Current app + backup + new app

        let availableSpace = try getAvailableDiskSpace()

        guard availableSpace > requiredSpace else {
            let errorMessage =
                "Insufficient disk space. Required: \(requiredSpace.formattedBytes), Available: \(availableSpace.formattedBytes)"
            Log.error("\(errorMessage)")
            throw createSafetyError(errorMessage)
        }

        Log.success("Disk space verification passed. Available: \(availableSpace.formattedBytes), Required: \(requiredSpace.formattedBytes)")
    }

    private func verifyCurrentAppIntegrity() async throws {
        Log.info("Verifying current application integrity")

        let currentAppURL = Bundle.main.bundleURL

        // Check bundle structure
        try verifyAppBundleStructureAndContents(currentAppURL)

        // Check executable
        guard let executablePath = Bundle.main.executablePath,
              fileManager.fileExists(atPath: executablePath) else {
            throw createSafetyError("Current application executable not found")
        }

        // Check permissions
        let attributes = try fileManager.attributesOfItem(atPath: executablePath)
        let permissions = attributes[.posixPermissions] as? NSNumber
        guard let permissions, permissions.intValue & 0o111 != 0 else {
            throw createSafetyError("Current application executable lacks execute permissions")
        }

        Log.success("Current application integrity verified")
    }

    private func verifyInstallationPermissions() async throws {
        Log.info("Verifying installation permissions")

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

        Log.success("Installation permissions verified")
    }

    private func verifySystemRequirements(manifest: UpdateManifest) throws {
        Log.info("Verifying system requirements")

        let currentOS = ProcessInfo.processInfo.operatingSystemVersion
        let minimumOS = manifest.minimumOS

        // Parse minimum OS version (assuming format like "13.0")
        let components = minimumOS.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 2 else {
            Log.warn("Could not parse minimum OS version: \(minimumOS)")
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

        Log.success("System requirements verified")
    }

    private func checkForConflictingRunningProcesses() async throws {
        Log.info("Checking for interfering processes")

        // Check if any other updater processes are running
        let runningApps = NSWorkspace.shared.runningApplications
        let interferingApps = runningApps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return bundleId.contains("updater") || bundleId.contains("installer")
        }

        if !interferingApps.isEmpty {
            let appNames = interferingApps.compactMap(\.localizedName).joined(separator: ", ")
            Log.warn("Found potentially interfering processes: \(appNames)")
        }

        Log.success("Process interference check completed")
    }

    // MARK: - Download Verification

    private func verifyDownloadIntegrity(_ downloadURL: URL, manifest: UpdateManifest) async throws {
        try checkCancellation()
        Log.info("Performing comprehensive download verification")

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

        Log.info("Download file size: \(fileSize.formattedBytes)")

        // Checksum verification
        try await fileVerifier.verifyDownloadedFile(downloadURL, manifest: manifest)

        Log.success("Download integrity verification completed")
    }

    // MARK: - Extraction with Verification

    private func extractAndVerifyUpdate(_ downloadURL: URL) async throws -> URL {
        try checkCancellation()
        Log.info("Extracting update with comprehensive verification")

        let tempDir = createTemporaryExtractionDirectory()

        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Extract with safety checks
            try await extractZipFile(downloadURL, to: tempDir)

            // Verify extraction completed successfully
            try await verifyExtractionCompleteness(tempDir)

            return tempDir
        } catch {
            // Clean up on failure
            try? fileManager.removeItem(at: tempDir)
            throw error
        }
    }

    private func extractZipFile(_ zipURL: URL, to destinationURL: URL) async throws {
        try validateZipFile(zipURL)

        try await withCheckedThrowingContinuation { continuation in
            Self.extractionQueue.async {
                do {
                    try self.performSafeZipExtraction(zipURL: zipURL, destinationURL: destinationURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func performSafeZipExtraction(zipURL: URL, destinationURL: URL) throws {
        Log.info("Extracting ZIP archive: \(zipURL.lastPathComponent)")

        guard let archive = Archive(url: zipURL, accessMode: .read) else {
            throw createExtractionError("Could not open ZIP archive", code: -1, zipURL: zipURL)
        }

        for entry in archive {
            try checkCancellation()
            _ = try archive.extract(entry, to: destinationURL.appendingPathComponent(entry.path))
        }

        Log.success("Successfully extracted ZIP archive")
    }

    private func verifyExtractionCompleteness(_ extractedURL: URL) async throws {
        Log.info("Verifying extraction completeness")

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

        Log.success("Extraction completeness verified")
    }

    // MARK: - Extraction Integrity Verification

    private func verifyExtractionIntegrity(_ extractedURL: URL, manifest: UpdateManifest) async throws {
        try checkCancellation()
        Log.info("Performing extraction integrity verification")

        // Find and verify app bundle
        let appBundle = try findAppBundle(in: extractedURL)

        try await performPostExtractionSafetyChecks(appBundle, manifest: manifest)

        Log.success("Extraction integrity verification completed")
    }

    private func performPostExtractionSafetyChecks(_ appBundle: URL, manifest: UpdateManifest) async throws {
        Log.info("Performing additional extraction safety checks")

        // Verify Info.plist content
        try verifyExtractedAppInfoPlistContent(appBundle, manifest: manifest)

        // Verify executable integrity
        try verifyExtractedAppExecutableIntegrity(appBundle)

        // Validate app bundle signature/code signature
        try await validateExtractedAppBundleSignature(appBundle)

        // Validate app launch capability
        try validateExtractedAppLaunchCapability(appBundle)

        // Validate app system compatibility
        try validateExtractedAppSystemCompatibility(appBundle, manifest: manifest)

        Log.success("Additional extraction checks completed")
    }

    private func verifyExtractedAppInfoPlistContent(_ appBundle: URL, manifest: UpdateManifest) throws {
        let infoPlistURL = appBundle.appendingPathComponent("Contents/Info.plist")

        guard let plist = NSDictionary(contentsOf: infoPlistURL) else {
            throw createSafetyError("Could not read Info.plist from extracted app")
        }

        // Verify version information
        guard let version = plist["CFBundleShortVersionString"] as? String,
              let buildString = plist["CFBundleVersion"] as? String,
              let build = Int(buildString) else {
            throw createSafetyError("Invalid version information in extracted app's Info.plist")
        }

        // Normalize version strings for comparison (remove emoji prefixes)
        let normalizedAppVersion = version.replacingOccurrences(of: "🧪 ", with: "")
        let normalizedManifestVersion = manifest.version.replacingOccurrences(of: "🧪 ", with: "")

        Log.debug("Version validation: app='\(version)' normalized='\(normalizedAppVersion)', manifest='\(manifest.version)' normalized='\(normalizedManifestVersion)', build=\(build) vs \(manifest.buildNumber)")

        guard normalizedAppVersion == normalizedManifestVersion, build == manifest.buildNumber else {
            Log.error("Version validation failed: normalized app='\(normalizedAppVersion)' != manifest='\(normalizedManifestVersion)' or build \(build) != \(manifest.buildNumber)")
            throw createSafetyError(
                "Version mismatch in extracted app. Expected: \(manifest.version)(\(manifest.buildNumber)), Got: \(version)(\(build))"
            )
        }
    }

    private func validateExtractedAppLaunchCapability(_ appBundle: URL) throws {
        Log.info("Validating extracted app launch capability")

        let infoPlistURL = appBundle.appendingPathComponent("Contents/Info.plist")

        guard let plist = NSDictionary(contentsOf: infoPlistURL) else {
            throw createSafetyError("Could not read Info.plist for launch capability validation")
        }

        // Check for required launch properties
        guard let bundleIdentifier = plist["CFBundleIdentifier"] as? String,
              !bundleIdentifier.isEmpty else {
            throw createSafetyError("App bundle missing or invalid CFBundleIdentifier")
        }

        guard let bundleName = plist["CFBundleName"] as? String,
              !bundleName.isEmpty else {
            throw createSafetyError("App bundle missing or invalid CFBundleName")
        }

        // Check that it's a proper application bundle
        guard let packageType = plist["CFBundlePackageType"] as? String,
              packageType == "APPL" else {
            throw createSafetyError("App bundle has invalid CFBundlePackageType (expected 'APPL')")
        }

        // Verify the main executable exists and is executable
        guard let executableName = plist["CFBundleExecutable"] as? String,
              !executableName.isEmpty else {
            throw createSafetyError("App bundle missing CFBundleExecutable")
        }

        let executablePath = appBundle.appendingPathComponent("Contents/MacOS/\(executableName)")
        guard fileManager.fileExists(atPath: executablePath.path) else {
            throw createSafetyError("Main executable not found: \(executableName)")
        }

        // Check executable permissions
        let executableAttributes = try fileManager.attributesOfItem(atPath: executablePath.path)
        guard let permissions = executableAttributes[.posixPermissions] as? NSNumber else {
            throw createSafetyError("Could not read executable permissions")
        }

        // Check if executable bit is set (at least one of owner/group/other execute bits)
        let perms = permissions.intValue
        guard perms & 0o111 != 0 else {
            throw createSafetyError("Main executable does not have execute permissions")
        }

        Log.success("App launch capability validation passed")
    }

    private func validateExtractedAppSystemCompatibility(_ appBundle: URL, manifest: UpdateManifest) throws {
        Log.info("Validating extracted app system compatibility")

        let currentOS = ProcessInfo.processInfo.operatingSystemVersion
        let infoPlistURL = appBundle.appendingPathComponent("Contents/Info.plist")

        guard let plist = NSDictionary(contentsOf: infoPlistURL) else {
            throw createSafetyError("Could not read Info.plist for system compatibility validation")
        }

        // Check minimum OS version
        if let minOSString = plist["LSMinimumSystemVersion"] as? String {
            let components = minOSString.split(separator: ".").compactMap { Int($0) }
            if components.count >= 2 {
                let minOSVersion = OperatingSystemVersion(
                    majorVersion: components[0],
                    minorVersion: components[1],
                    patchVersion: components.count > 2 ? components[2] : 0
                )

                guard ProcessInfo.processInfo.isOperatingSystemAtLeast(minOSVersion) else {
                    throw createSafetyError("App requires macOS \(minOSString) or later, current: \(currentOS.majorVersion).\(currentOS.minorVersion).\(currentOS.patchVersion)")
                }
            }
        }

        // Check supported architectures
        if let supportedArchitectures = plist["LSArchitecturePriority"] as? [String] {
            let currentArchitecture = SystemInfo.architecture
            guard supportedArchitectures.contains(currentArchitecture) else {
                throw createSafetyError("App does not support current architecture: \(currentArchitecture)")
            }
        }

        // Validate against manifest requirements
        let manifestMinOS = manifest.minimumOS
        let manifestComponents = manifestMinOS.split(separator: ".").compactMap { Int($0) }
        if manifestComponents.count >= 2 {
            let manifestMinVersion = OperatingSystemVersion(
                majorVersion: manifestComponents[0],
                minorVersion: manifestComponents[1],
                patchVersion: manifestComponents.count > 2 ? manifestComponents[2] : 0
            )

            guard ProcessInfo.processInfo.isOperatingSystemAtLeast(manifestMinVersion) else {
                throw createSafetyError("Update requires macOS \(manifestMinOS) or later")
            }
        }

        Log.success("App system compatibility validation passed")
    }

    private func validateExtractedAppBundleSignature(_ appBundle: URL) async throws {
        Log.info("Validating extracted app bundle signature")

        // Use the codesign command to verify the signature
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--verbose", appBundle.path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                Log.success("App bundle signature validation passed")
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown codesign error"
                Log.error("App bundle signature validation failed: \(errorOutput)")
                throw createSafetyError("App bundle signature validation failed: \(errorOutput)")
            }
        } catch {
            Log.error("Failed to run codesign verification: \(error)")
            throw createSafetyError("Could not verify app bundle signature: \(error.localizedDescription)")
        }
    }

    private func verifyExtractedAppExecutableIntegrity(_ appBundle: URL) throws {
        Log.info("Verifying executable integrity")

        let macOSDirectory = appBundle.appendingPathComponent("Contents/MacOS")

        guard fileManager.fileExists(atPath: macOSDirectory.path) else {
            throw createSafetyError("MacOS directory not found in app bundle")
        }

        let executables = try fileManager.contentsOfDirectory(at: macOSDirectory, includingPropertiesForKeys: nil)

        guard !executables.isEmpty else {
            throw createSafetyError("No executables found in MacOS directory")
        }

        for executable in executables {
            let attributes = try fileManager.attributesOfItem(atPath: executable.path)
            let permissions = attributes[.posixPermissions] as? NSNumber

            if permissions == nil || permissions!.intValue & 0o111 == 0 {
                Log.warn("Executable lacks execute permissions: \(executable.path)")
            }

            let fileSize = attributes[.size] as? Int64 ?? 0
            guard fileSize > 0 else {
                throw createSafetyError("Executable file is empty: \(executable.path)")
            }
        }

        Log.success("Executable integrity verified")
    }

    // MARK: - Safe Installation

    private func performSafeInstallation(from extractedURL: URL, manifest: UpdateManifest) async throws {
        try checkCancellation()
        Log.info("Performing safe installation")

        // Pre-installation verification
        try await verifyPreInstallationState()

        // Perform installation with coordinator
        try await coordinator.performInstallation(from: extractedURL, manifest: manifest)

        // Post-installation verification
        try await verifyPostInstallationState(manifest: manifest)

        Log.success("Safe installation completed")
    }

    private func verifyPreInstallationState() async throws {
        Log.info("Verifying pre-installation state")

        let currentAppURL = Bundle.main.bundleURL

        // Ensure current app still exists and is valid
        guard fileManager.fileExists(atPath: currentAppURL.path) else {
            throw createSafetyError("Current application no longer exists before installation")
        }

        try verifyAppBundleStructureAndContents(currentAppURL)

        Log.success("Pre-installation state verified")
    }

    private func verifyPostInstallationState(manifest: UpdateManifest) async throws {
        Log.info("Verifying post-installation state")

        let currentAppURL = Bundle.main.bundleURL

        // Ensure app still exists after installation
        guard fileManager.fileExists(atPath: currentAppURL.path) else {
            throw createSafetyError("Application missing after installation - CRITICAL ERROR")
        }

        // Verify structure
        try verifyAppBundleStructureAndContents(currentAppURL)

        // Verify it's the correct version
        let infoPlistURL = currentAppURL.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: infoPlistURL),
              let version = plist["CFBundleShortVersionString"] as? String else {
            throw createSafetyError("Cannot read version from installed application")
        }

        // Normalize version strings for comparison (remove emoji prefixes)
        let normalizedInstalledVersion = version.replacingOccurrences(of: "🧪 ", with: "")
        let normalizedManifestVersion = manifest.version.replacingOccurrences(of: "🧪 ", with: "")

        guard normalizedInstalledVersion == normalizedManifestVersion else {
            throw createSafetyError(
                "Installed version (\(version)) does not match expected version (\(manifest.version))"
            )
        }

        Log.success("Post-installation state verified")
    }

    // MARK: - Comprehensive Verification

    private func performComprehensiveVerification(manifest: UpdateManifest) async throws {
        try checkCancellation()
        Log.info("Performing comprehensive installation verification")

        // Standard verification
        try await verifyInstallation(manifest: manifest)

        // Additional comprehensive checks
        try await performFinalInstallationVerificationChecks(manifest: manifest)

        Log.success("Comprehensive verification completed")
    }

    private func performFinalInstallationVerificationChecks(manifest _: UpdateManifest) async throws {
        Log.info("Performing additional verification checks")

        let currentAppURL = Bundle.main.bundleURL

        // Verify app can be read
        guard fileManager.isReadableFile(atPath: currentAppURL.path) else {
            throw createSafetyError("Installed application is not readable")
        }

        // Verify essential components
        try verifyAppBundleEssentialComponents(currentAppURL)

        // Verify permissions
        try verifyAppPermissions(currentAppURL)

        Log.success("Additional verification checks completed")
    }

    private func verifyAppBundleEssentialComponents(_ appURL: URL) throws {
        Log.info("Verifying essential app components")

        let essentialPaths = [
            "Contents/Info.plist",
            "Contents/MacOS",
            "Contents/Resources"
        ]

        for path in essentialPaths {
            let componentURL = appURL.appendingPathComponent(path)
            guard fileManager.fileExists(atPath: componentURL.path) else {
                throw createSafetyError("Essential component missing: \(path)")
            }
        }

        // Verify MacOS directory has executables
        let macOSURL = appURL.appendingPathComponent("Contents/MacOS")
        let executables = try fileManager.contentsOfDirectory(at: macOSURL, includingPropertiesForKeys: nil)

        guard !executables.isEmpty else {
            throw createSafetyError("No executables found in MacOS directory")
        }

        Log.success("Essential components verified")
    }

    private func verifyAppPermissions(_ appURL: URL) throws {
        Log.info("Verifying app permissions")

        let macOSURL = appURL.appendingPathComponent("Contents/MacOS")
        let executables = try fileManager.contentsOfDirectory(at: macOSURL, includingPropertiesForKeys: nil)

        for executable in executables {
            let attributes = try fileManager.attributesOfItem(atPath: executable.path)
            let permissions = attributes[.posixPermissions] as? NSNumber

            guard let permissions, permissions.intValue & 0o111 != 0 else {
                throw createSafetyError("Executable lacks execute permissions: \(executable.lastPathComponent)")
            }
        }

        Log.success("App permissions verified")
    }

    // MARK: - Pre-Restart Verification

    private func performPreRestartSafetyChecks() throws {
        Log.info("Performing pre-restart verification")

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

        Log.success("Pre-restart verification passed")
    }

    // MARK: - Enhanced Validation Methods

    private func validateZipFile(_ zipURL: URL) throws {
        Log.info("Validating ZIP file: \(zipURL.path)")

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

        Log.success("ZIP file validation passed")
    }

    // MARK: - Standard Methods (Enhanced)

    private func verifyInstallation(manifest: UpdateManifest) async throws {
        try checkCancellation()

        Log.info("Verifying installation success")
        Log.info("Expected version: \(manifest.version)")
        Log.info("Expected build: \(manifest.buildNumber)")

        let installedVersion = try getInstalledVersion()
        Log.info("Currently installed version: \(installedVersion)")

        // Normalize version strings for comparison (remove emoji prefixes)
        let normalizedInstalledVersion = installedVersion.replacingOccurrences(of: "🧪 ", with: "")
        let normalizedManifestVersion = manifest.version.replacingOccurrences(of: "🧪 ", with: "")

        guard normalizedInstalledVersion == normalizedManifestVersion else {
            let errorMessage = "Installed version \(installedVersion) doesn't match expected \(manifest.version)"
            Log.error("Version mismatch: installed=\(installedVersion), expected=\(manifest.version)")
            throw UpdateError.installationFailed(NSError(
                domain: "VersionMismatch",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            ))
        }

        Log.success("Installation verification completed successfully")
    }

    private func getInstalledVersion() throws -> String {
        let bundlePath = Bundle.main.bundlePath
        let infoPlistPath = "\(bundlePath)/Contents/Info.plist"

        guard let plist = NSDictionary(contentsOfFile: infoPlistPath),
              let version = plist["CFBundleShortVersionString"] as? String else {
            throw UpdateError.installationFailed(NSError(domain: "VersionRead", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Could not read version from installed application"
            ]))
        }

        return version
    }

    private func performSafeCleanup(_ extractedURL: URL, _ downloadURL: URL) async throws {
        Log.info("Performing safe cleanup of temporary files")

        let cleanupOperations = [
            (extractedURL, "extraction directory"),
            (downloadURL, "download file")
        ]

        for (url, description) in cleanupOperations {
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                    Log.debug("Removed \(description): \(url.path)")
                } catch {
                    Log.warn("Failed to clean up \(description): \(error)")
                    // Don't fail installation for cleanup issues
                }
            }
        }

        Log.success("Safe cleanup completed")
    }

    // MARK: - Utility Methods

    private func checkCancellation() throws {
        guard !isCancelled else {
            throw UpdateError.installationFailed(NSError(
                domain: "Installation",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Installation cancelled"]
            ))
        }
    }

    private func attemptApplicationRestart(appURL: URL) {
        Log.info("Attempting application restart")

        do {
            try NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
            Log.success("Application restart initiated via NSWorkspace")
        } catch {
            Log.warn("NSWorkspace restart failed, trying fallback: \(error)")
            fallbackApplicationRestart(appPath: appURL.path)
        }
    }

    private func fallbackApplicationRestart(appPath: String) {
        Log.info("Attempting fallback application restart")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [appPath]

        do {
            try task.run()
            Log.success("Application restart initiated via fallback method")
        } catch {
            Log.error("Failed to restart application via fallback: \(error)")
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
                Log.info("Found app bundle: \(item.lastPathComponent)")
                return item
            }

            let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory == true,
               let found = try? findAppBundle(in: item) {
                return found
            }
        }

        let fileList = contents.map(\.lastPathComponent).joined(separator: ", ")
        Log.error("No .app bundle found in extracted files. Available files: \(fileList)")

        throw UpdateError.installationFailed(
            NSError(
                domain: "AppBundleNotFound",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No .app bundle found in update package. Found files: \(fileList)"]
            )
        )
    }

    private func verifyAppBundleStructureAndContents(_ bundleURL: URL) throws {
        Log.debug("Verifying bundle structure for: \(bundleURL.lastPathComponent)")

        let requiredPaths = ["Contents/Info.plist", "Contents/MacOS"]

        for path in requiredPaths {
            let fullPath = bundleURL.appendingPathComponent(path)
            guard fileManager.fileExists(atPath: fullPath.path) else {
                Log.error("Missing required path: \(path)")
                throw createSafetyError("Invalid app bundle: missing \(path)")
            }
        }

        Log.debug("Bundle structure verification passed")
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
        UpdateError.installationFailed(NSError(
            domain: "SafetyCheck",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: message]
        ))
    }

    private func createExtractionError(_ message: String, code: Int, zipURL: URL? = nil) -> UpdateError {
        var userInfo = [NSLocalizedDescriptionKey: message]
        if let zipURL {
            let fileSize = try? fileManager.attributesOfItem(atPath: zipURL.path)[.size] as? Int64
            let fileSizeString = fileSize?.formattedBytes ?? "unknown size"
            userInfo[NSLocalizedDescriptionKey] = "\(message) at \(zipURL.path) (Size: \(fileSizeString))"
        }

        return UpdateError.installationFailed(NSError(
            domain: "ZipExtraction",
            code: code,
            userInfo: userInfo
        ))
    }
}

// MARK: - InstallationState

private enum InstallationState {
    case idle, inProgress, completed, failed, cancelled
}

// MARK: - InstallationSteps

private struct InstallationSteps {
    let all: [InstallationStep] = [
        InstallationStep(type: .preCheck, progress: 0.05, phase: .checking),
        InstallationStep(type: .verifyDownload, progress: 0.25, phase: .downloading),
        InstallationStep(type: .extract, progress: 0.45, phase: .extracting),
        InstallationStep(type: .verifyExtraction, progress: 0.65, phase: .verifying),
        InstallationStep(type: .install, progress: 0.80, phase: .installing),
        InstallationStep(type: .verify, progress: 0.90, phase: .verifying)
    ]
}

// MARK: - InstallationStep

private struct InstallationStep {
    let type: InstallationStepType
    let progress: Double
    let phase: UpdateProgress.UpdatePhase
}

// MARK: - InstallationStepType

private enum InstallationStepType {
    case preCheck, verifyDownload, extract, verifyExtraction, install, verify, cleanup
}
