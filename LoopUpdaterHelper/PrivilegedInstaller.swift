//
//  PrivilegedInstaller.swift
//  Loop
//
//  Created by Kai Azim on 2026-03-01.
//

import Foundation
import Scribe
import Security

@Loggable
final class PrivilegedInstaller: NSObject, PrivilegedInstallerProtocol {
    private struct AtomicSwapPaths {
        let currentURL: URL
        let stagedURL: URL
        let backupURL: URL
    }

    private struct RestorePaths {
        let currentURL: URL
        let backupURL: URL
    }

    private static let maxRollbackIDLength = 128
    private static let allowedRollbackIDScalars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")

    private let context: PrivilegedInstallerService.TrustedClientContext
    private let fileManager: FileManager

    init(
        context: PrivilegedInstallerService.TrustedClientContext,
        fileManager: FileManager = .default
    ) {
        self.context = context
        self.fileManager = fileManager
    }

    func atomicSwap(rollbackID: String, withReply reply: @escaping (NSError?) -> ()) {
        do {
            try executeAtomicSwap(rollbackID: rollbackID)
            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    func restoreFromBackup(rollbackID: String, withReply reply: @escaping (NSError?) -> ()) {
        do {
            try executeRestoreFromBackup(rollbackID: rollbackID)
            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    /// Executes a privileged atomic swap using rollback-token-derived paths in user Application Support.
    private func executeAtomicSwap(rollbackID: String) throws {
        let operation = "atomic swap"

        do {
            let paths = try deriveAndValidateAtomicSwapPaths(
                for: rollbackID,
                operation: operation
            )
            try validateBundleForInstall(
                at: paths.stagedURL,
                operation: operation,
                rollbackID: rollbackID
            )

            try performAtomicSwap(
                currentURL: paths.currentURL,
                stagedURL: paths.stagedURL,
                backupURL: paths.backupURL
            )
        } catch {
            log.error("Privileged \(operation) failed for rollbackID \(rollbackID): \(error.localizedDescription)")
            throw error
        }
    }

    /// Restores the current app directly from rollback-token-derived backup path in user Application Support.
    private func executeRestoreFromBackup(rollbackID: String) throws {
        let operation = "restore"

        do {
            let paths = try deriveAndValidateRestorePaths(
                for: rollbackID,
                operation: operation
            )

            guard fileManager.fileExists(atPath: paths.backupURL.path) else {
                log.info("No backup found at \(paths.backupURL.path); privileged restore is a no-op")
                return
            }

            try validateBundleForInstall(
                at: paths.backupURL,
                operation: operation,
                rollbackID: rollbackID
            )

            try performRestoreFromBackup(
                currentURL: paths.currentURL,
                backupURL: paths.backupURL
            )
        } catch {
            log.error("Privileged \(operation) failed for rollbackID \(rollbackID): \(error.localizedDescription)")
            throw error
        }
    }

    /// Derives and validates atomic swap paths from trusted connection context and rollback token.
    private func deriveAndValidateAtomicSwapPaths(
        for rollbackID: String,
        operation: String
    ) throws -> AtomicSwapPaths {
        try validateRollbackID(rollbackID, operation: operation)

        let currentURL = LoopSupportPaths.canonical(context.clientBundleURL)
        let stagedURL = LoopSupportPaths.canonical(
            context.stagingRoot.appendingPathComponent(
                "\(context.clientBundleURL.lastPathComponent).staging",
                isDirectory: true
            )
        )
        let backupURL = LoopSupportPaths.canonical(
            context.rollbackRoot.appendingPathComponent(rollbackID, isDirectory: true)
        )

        try ensurePathInside(
            stagedURL,
            root: context.stagingRoot,
            operation: operation,
            rollbackID: rollbackID,
            role: "staged bundle",
            expectedDescription: "Loop staging directory"
        )
        try ensurePathInside(
            backupURL,
            root: context.rollbackRoot,
            operation: operation,
            rollbackID: rollbackID,
            role: "backup bundle",
            expectedDescription: "Loop rollback directory"
        )

        return AtomicSwapPaths(
            currentURL: currentURL,
            stagedURL: stagedURL,
            backupURL: backupURL
        )
    }

    /// Derives and validates restore paths from trusted connection context and rollback token.
    private func deriveAndValidateRestorePaths(
        for rollbackID: String,
        operation: String
    ) throws -> RestorePaths {
        try validateRollbackID(rollbackID, operation: operation)

        let currentURL = LoopSupportPaths.canonical(context.clientBundleURL)
        let backupURL = LoopSupportPaths.canonical(
            context.rollbackRoot.appendingPathComponent(rollbackID, isDirectory: true)
        )

        try ensurePathInside(
            backupURL,
            root: context.rollbackRoot,
            operation: operation,
            rollbackID: rollbackID,
            role: "backup bundle",
            expectedDescription: "Loop rollback directory"
        )

        return RestorePaths(
            currentURL: currentURL,
            backupURL: backupURL
        )
    }

    /// Validates bundle code signature using the same static validation path as non-privileged install flow.
    private func validateBundleForInstall(
        at bundleURL: URL,
        operation: String,
        rollbackID: String
    ) throws {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: bundleURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw bundleValidationFailure(
                operation: operation,
                rollbackID: rollbackID,
                path: bundleURL.path,
                reason: "Bundle path does not exist or is not a directory"
            )
        }

        var staticCode: SecStaticCode?
        let creationStatus = SecStaticCodeCreateWithPath(bundleURL as CFURL, SecCSFlags(), &staticCode)
        guard creationStatus == errSecSuccess, let staticCode else {
            throw bundleValidationFailure(
                operation: operation,
                rollbackID: rollbackID,
                path: bundleURL.path,
                reason: "Could not create static code object: \(securityErrorMessage(for: creationStatus))"
            )
        }

        let validationFlags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures)
        let validationStatus = SecStaticCodeCheckValidity(staticCode, validationFlags, nil)
        guard validationStatus == errSecSuccess else {
            throw bundleValidationFailure(
                operation: operation,
                rollbackID: rollbackID,
                path: bundleURL.path,
                reason: "Code signature validation failed: \(securityErrorMessage(for: validationStatus))"
            )
        }
    }

    /// Validates rollback token format to prevent traversal and unexpected path materialization.
    private func validateRollbackID(_ rollbackID: String, operation: String) throws {
        guard !rollbackID.isEmpty else {
            throw pathValidationFailure(
                operation: operation,
                rollbackID: rollbackID,
                path: rollbackID,
                reason: "Rollback ID must not be empty"
            )
        }

        guard rollbackID.count <= Self.maxRollbackIDLength else {
            throw pathValidationFailure(
                operation: operation,
                rollbackID: rollbackID,
                path: rollbackID,
                reason: "Rollback ID exceeds \(Self.maxRollbackIDLength) characters"
            )
        }

        guard rollbackID != ".", rollbackID != ".." else {
            throw pathValidationFailure(
                operation: operation,
                rollbackID: rollbackID,
                path: rollbackID,
                reason: "Rollback ID cannot be a directory traversal segment"
            )
        }

        guard rollbackID.unicodeScalars.allSatisfy({ Self.allowedRollbackIDScalars.contains($0) }) else {
            throw pathValidationFailure(
                operation: operation,
                rollbackID: rollbackID,
                path: rollbackID,
                reason: "Rollback ID contains invalid characters"
            )
        }
    }

    /// Ensures a candidate path remains within the expected root after canonicalization.
    private func ensurePathInside(
        _ candidate: URL,
        root: URL,
        operation: String,
        rollbackID: String,
        role: String,
        expectedDescription: String
    ) throws {
        guard isPath(candidate, inside: root) else {
            throw pathValidationFailure(
                operation: operation,
                rollbackID: rollbackID,
                path: candidate.path,
                reason: "\(role) must be inside \(expectedDescription): \(root.path)"
            )
        }
    }

    /// Converts Security framework status codes to readable log/error strings.
    private func securityErrorMessage(for status: OSStatus) -> String {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return "\(message) (OSStatus \(status))"
        }
        return "OSStatus \(status)"
    }

    /// Logs and constructs a privileged path validation failure with operation context.
    private func pathValidationFailure(
        operation: String,
        rollbackID: String,
        path: String,
        reason: String
    ) -> PrivilegedInstallerError {
        log.warn(
            """
            Rejected privileged \(operation) path for pid \(context.clientPID), uid \(context.clientUID), rollbackID \(rollbackID). \
            Path: \(path). Reason: \(reason). \
            Expected support root: \(context.loopSupportRoot.path)
            """
        )

        return .pathValidationFailed(operation: operation, path: path, reason: reason)
    }

    /// Logs and constructs a privileged bundle validation failure with operation context.
    private func bundleValidationFailure(
        operation: String,
        rollbackID: String,
        path: String,
        reason: String
    ) -> PrivilegedInstallerError {
        log.warn(
            """
            Rejected privileged \(operation) bundle for pid \(context.clientPID), uid \(context.clientUID), rollbackID \(rollbackID). \
            Bundle path: \(path). Reason: \(reason). \
            Expected support root: \(context.loopSupportRoot.path)
            """
        )

        return .bundleValidationFailed(path: path, reason: reason)
    }

    /// Returns true when a canonicalized URL is equal to or contained within a canonicalized root.
    private func isPath(_ url: URL, inside root: URL) -> Bool {
        let canonicalURLPath = LoopSupportPaths.canonical(url).path
        let canonicalRootPath = LoopSupportPaths.canonical(root).path
        return canonicalURLPath == canonicalRootPath || canonicalURLPath.hasPrefix("\(canonicalRootPath)/")
    }

    /// Moves current app to backup and installs the staged app atomically with rollback on failure.
    private func performAtomicSwap(currentURL: URL, stagedURL: URL, backupURL: URL) throws {
        log.info("Starting privileged atomic swap")
        log.info("Current app: \(currentURL.path)")
        log.info("Staged app: \(stagedURL.path)")
        log.info("Backup app: \(backupURL.path)")

        let backupUID = context.clientUID
        let backupGID = context.clientGID
        log.success("Using backup ownership uid/gid from authenticated client (uid: \(backupUID), gid: \(backupGID))")

        let backupParent = backupURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: backupParent, withIntermediateDirectories: true)
        log.success("Backup directory ready at \(backupParent.path)")

        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
            log.success("Removed existing backup at \(backupURL.path)")
        }

        try fileManager.moveItem(at: currentURL, to: backupURL)
        log.success("Moved current app to backup location")
        try applyOwnershipRecursively(at: backupURL, uid: backupUID, gid: backupGID)
        log.success("Applied client ownership to backup")

        do {
            try fileManager.moveItem(at: stagedURL, to: currentURL)
            log.success("Moved staged app into current location")
            try applyRootOwnershipRecursively(at: currentURL)
            log.success("Applied root ownership to installed app")
        } catch {
            log.warn("Swap failed after backup move; attempting rollback")
            try? fileManager.removeItem(at: currentURL)
            try? fileManager.moveItem(at: backupURL, to: currentURL)
            try? applyRootOwnershipRecursively(at: currentURL)
            log.success("Rollback to backup completed")
            throw error
        }

        log.success("Privileged atomic swap completed")
    }

    /// Restores the app from backup and reapplies root ownership.
    private func performRestoreFromBackup(currentURL: URL, backupURL: URL) throws {
        log.info("Starting privileged restore from backup")
        log.info("Current app: \(currentURL.path)")
        log.info("Backup app: \(backupURL.path)")

        if fileManager.fileExists(atPath: currentURL.path) {
            try fileManager.removeItem(at: currentURL)
            log.success("Removed current app before restore")
        }

        try fileManager.moveItem(at: backupURL, to: currentURL)
        try applyRootOwnershipRecursively(at: currentURL)
        log.success("Privileged restore completed")
    }

    /// Applies root ownership recursively to a directory tree.
    private func applyRootOwnershipRecursively(at url: URL) throws {
        log.info("Applying root ownership recursively at \(url.path)")
        try applyOwnershipRecursively(at: url, uid: 0, gid: 0)
        log.success("Applied root ownership recursively at \(url.path)")
    }

    /// Applies a target uid/gid recursively to the root URL and its descendants.
    private func applyOwnershipRecursively(at rootURL: URL, uid: uid_t, gid: gid_t) throws {
        var itemCount = 0
        try applyOwnership(to: rootURL, uid: uid, gid: gid)
        itemCount += 1

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: nil
        ) else {
            log.success("Applied ownership to \(itemCount) items under \(rootURL.path)")
            return
        }

        while let itemURL = enumerator.nextObject() as? URL {
            try applyOwnership(to: itemURL, uid: uid, gid: gid)
            itemCount += 1
        }

        log.success("Applied ownership to \(itemCount) items under \(rootURL.path)")
    }

    /// Applies ownership to a single filesystem entry using `lchown`.
    private func applyOwnership(to itemURL: URL, uid: uid_t, gid: gid_t) throws {
        let result: Int32 = itemURL.withUnsafeFileSystemRepresentation { path in
            guard let path else {
                return -1
            }
            return lchown(path, uid, gid)
        }

        guard result == 0 else {
            let errorCode = errno
            throw PrivilegedInstallerError.ownershipChangeFailed(url: itemURL, code: errorCode)
        }

        log.success("Applied ownership to \(itemURL.path) (uid: \(uid), gid: \(gid))")
    }
}
