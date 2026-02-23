//
//  BackupManager.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-23.
//

import Foundation
import Scribe

struct BackupCleanupReport: Sendable {
    let permissionDeniedPaths: [URL]
    let removedCount: Int
    let remainingSize: Int64
    let otherFailures: [String]

    static func noCleanup(remainingSize: Int64) -> Self {
        Self(
            permissionDeniedPaths: [],
            removedCount: 0,
            remainingSize: remainingSize,
            otherFailures: []
        )
    }
}

@Loggable
actor BackupManager {
    private let fileManager: FileManager

    private var backupDirectory: URL { SystemPaths.backupsDirectory }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    private static let maxBackupSize: Int64 = 104_857_600 // 100MB

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Public Interface

    /// Ensures backup directory exists and tries to clean up old backups if size exceeds limit.
    /// Cleanup is best-effort so stale protected backups never block a new update.
    func prepareForBackup() async throws -> BackupCleanupReport {
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let backupSize = try calculateDirectorySize(backupDirectory)

        guard backupSize > Self.maxBackupSize else {
            return .noCleanup(remainingSize: backupSize)
        }

        log.info("Backup directory exceeds 100MB (\(backupSize.formattedBytes)), cleaning up old backups")
        return cleanupOldBackupsBestEffort(currentSize: backupSize, maxSize: Self.maxBackupSize)
    }

    /// Creates a unique backup URL for the current app version
    /// - Returns: URL where the backup should be stored
    func createBackupURL() throws -> URL {
        let baseTimestamp = Self.dateFormatter.string(from: Date())
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        var backupName = "backup_\(currentVersion)_\(baseTimestamp)"
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
            throw UpdateError.installationFailed("Could not generate unique install backup name after \(attempt) attempts")
        }

        return backupURL
    }

    /// Restores the application from a backup after a failed installation
    /// - Parameters:
    ///   - currentURL: The current (possibly corrupted) app location
    ///   - backupURL: The backup location to restore from
    func restoreFromBackup(currentURL: URL, backupURL: URL) throws {
        guard fileManager.fileExists(atPath: backupURL.path) else {
            log.warn("No backup found to restore from at: \(backupURL.path)")
            return
        }

        log.info("Attempting to restore from backup...")
        try? fileManager.removeItem(at: currentURL)
        try? fileManager.moveItem(at: backupURL, to: currentURL)
        log.info("Restored from backup")
    }

    // MARK: - Private Methods

    private func cleanupOldBackupsBestEffort(currentSize: Int64, maxSize: Int64) -> BackupCleanupReport {
        let backups: [(URL, Date)]
        do {
            backups = try getBackupsSortedByDate()
        } catch {
            let message = "Unable to enumerate backups for cleanup: \(error.localizedDescription)"
            log.warn(message)
            return BackupCleanupReport(
                permissionDeniedPaths: [],
                removedCount: 0,
                remainingSize: currentSize,
                otherFailures: [message]
            )
        }

        var remainingSize = currentSize
        var removedCount = 0
        var permissionDeniedPaths: [URL] = []
        var otherFailures: [String] = []

        for (backupURL, _) in backups {
            guard remainingSize > maxSize else { break }

            let backupItemSize = (try? calculateDirectorySize(backupURL)) ?? 0

            do {
                try fileManager.removeItem(at: backupURL)
                remainingSize -= backupItemSize
                removedCount += 1
                log.info("Removed old backup: \(backupURL.lastPathComponent) (\(backupItemSize.formattedBytes))")
            } catch {
                let failureMessage = "Could not remove old backup \(backupURL.lastPathComponent): \(error.localizedDescription)"
                log.warn(failureMessage)

                if isPermissionDenied(error) {
                    permissionDeniedPaths.append(backupURL)
                } else {
                    otherFailures.append(failureMessage)
                }
            }
        }

        if remainingSize > maxSize {
            log.warn("Backup cleanup incomplete (\(remainingSize.formattedBytes) > \(maxSize.formattedBytes)); continuing update")
        } else {
            log.info("Backup cleanup completed, new size: \(remainingSize.formattedBytes)")
        }

        return BackupCleanupReport(
            permissionDeniedPaths: permissionDeniedPaths,
            removedCount: removedCount,
            remainingSize: remainingSize,
            otherFailures: otherFailures
        )
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

        return Int64(
            enumerator
                .compactMap { $0 as? URL }
                .compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
                .reduce(0, +)
        )
    }

    private func isPermissionDenied(_ error: Error) -> Bool {
        let posixPermissionCodes: Set<Int> = [Int(EACCES), Int(EPERM)]
        let cocoaPermissionCodes: Set<Int> = [
            CocoaError.Code.fileWriteNoPermission.rawValue,
            CocoaError.Code.fileReadNoPermission.rawValue
        ]

        let errors = errorChain(from: error as NSError)
        return errors.contains { nsError in
            if nsError.domain == NSPOSIXErrorDomain {
                return posixPermissionCodes.contains(nsError.code)
            }

            if nsError.domain == NSCocoaErrorDomain {
                return cocoaPermissionCodes.contains(nsError.code)
            }

            return false
        }
    }

    private func errorChain(from error: NSError) -> [NSError] {
        var chain: [NSError] = [error]
        var current = error

        while let underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError {
            if chain.contains(where: { $0.domain == underlying.domain && $0.code == underlying.code }) {
                break
            }

            chain.append(underlying)
            current = underlying
        }

        return chain
    }
}
