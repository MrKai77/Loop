//
//  BackupManager.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-23.
//

import Foundation
import Scribe
import ZIPFoundation

@Loggable
actor BackupManager {
    private let fileManager: FileManager

    private var homeDirectory: URL { LoopSupportPaths.canonical(fileManager.homeDirectoryForCurrentUser) }
    private var backupDirectory: URL { LoopSupportPaths.backupsDirectory(homeDirectory: homeDirectory) }

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

    /// Ensures backup directory exists, removes non-zip backup items, and cleans old archives when needed.
    func prepareForBackup() async throws {
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        purgeNonZipBackups()

        let backupSize = try fileManager.calculateDirectorySize(backupDirectory)

        guard backupSize > Self.maxBackupSize else {
            return
        }

        log.info("Backup directory exceeds 100MB (\(backupSize.formattedBytes)), cleaning up old backups")
        cleanupOldBackupsBestEffort(currentSize: backupSize, maxSize: Self.maxBackupSize)
    }

    /// Archives a rollback bundle into a persistent zip backup.
    /// - Parameter fileURL: Path of the rollback bundle to archive.
    /// - Returns: URL of the created zip archive.
    func backup(fileURL: URL) async throws -> URL {
        try await prepareForBackup()

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw UpdateError.installationFailed("Backup source does not exist at \(fileURL.path)")
        }

        let archiveURL = try createBackupArchiveURL()
        do {
            try fileManager.zipItem(at: fileURL, to: archiveURL, shouldKeepParent: true)
            try fileManager.removeItem(at: fileURL)
            log.info("Created backup archive: \(archiveURL.lastPathComponent)")
            return archiveURL
        } catch {
            try? fileManager.removeItem(at: archiveURL)
            throw UpdateError.installationFailed(
                "Could not create backup archive \(archiveURL.lastPathComponent): \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Private Methods

    /// Used to purge old backups from Loop 1.4.x, which stored `.app`s instead of `.zip`s.
    private func purgeNonZipBackups() {
        let backupItems: [URL]
        do {
            backupItems = try fileManager.contentsOfDirectory(
                at: backupDirectory,
                includingPropertiesForKeys: nil
            )
        } catch {
            log.warn("Unable to enumerate backups for zip filtering: \(error.localizedDescription)")
            return
        }

        for backupItem in backupItems {
            guard backupItem.pathExtension.lowercased() != "zip" else {
                continue
            }

            do {
                try fileManager.removeItem(at: backupItem)
                log.info("Removed non-zip backup item: \(backupItem.lastPathComponent)")
            } catch {
                log.warn("Could not remove non-zip backup item \(backupItem.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    private func cleanupOldBackupsBestEffort(currentSize: Int64, maxSize: Int64) {
        let backups: [(URL, Date)]
        do {
            backups = try getBackupArchivesSortedByDate()
        } catch {
            let message = "Unable to enumerate backups for cleanup: \(error.localizedDescription)"
            log.warn(message)
            return
        }

        var remainingSize = currentSize

        for (backupURL, _) in backups {
            guard remainingSize > maxSize else { break }

            let backupItemSize = (try? fileManager.calculateDirectorySize(backupURL)) ?? 0

            do {
                try fileManager.removeItem(at: backupURL)
                remainingSize -= backupItemSize
                log.info("Removed old backup: \(backupURL.lastPathComponent) (\(backupItemSize.formattedBytes))")
            } catch {
                let failureMessage = "Could not remove old backup \(backupURL.lastPathComponent): \(error.localizedDescription)"
                log.warn(failureMessage)
            }
        }

        if remainingSize > maxSize {
            log.warn("Backup cleanup incomplete (\(remainingSize.formattedBytes) > \(maxSize.formattedBytes)); continuing update")
        } else {
            log.info("Backup cleanup completed, new size: \(remainingSize.formattedBytes)")
        }
    }

    private func getBackupArchivesSortedByDate() throws -> [(URL, Date)] {
        try fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "zip" }
        .compactMap { url -> (URL, Date)? in
            guard let date = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate else { return nil }
            return (url, date)
        }
        .sorted { $0.1 < $1.1 }
    }

    private func createBackupArchiveURL() throws -> URL {
        let baseTimestamp = Self.dateFormatter.string(from: Date())
        let currentVersion = Bundle.main.appVersion ?? "unknown"

        let backupArchiveURL = backupDirectory
            .appendingPathComponent("backup_\(currentVersion)_\(baseTimestamp)")
            .appendingPathExtension("zip")

        guard !fileManager.fileExists(atPath: backupArchiveURL.path) else {
            throw UpdateError.installationFailed("Could not generate unique backup archive name")
        }

        return backupArchiveURL
    }
}
