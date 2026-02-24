//
//  PrivilegedInstallerService.swift
//  Loop
//
//  Created by Kai Azim on 2026-02-23.
//

import AppKit
import Darwin
import Foundation
import Scribe
import Security

@Loggable
final class PrivilegedInstallerService: NSObject, NSXPCListenerDelegate, PrivilegedInstallerProtocol {
    private struct PathOwnership {
        let uid: uid_t
        let gid: gid_t
    }

    private let listener: NSXPCListener
    private let fileManager = FileManager.default

    init(serviceName: String) {
        self.listener = NSXPCListener(machServiceName: serviceName)
        super.init()
        listener.delegate = self
    }

    func run() {
        log.info("Starting privileged installer listener")
        listener.resume()
        log.success("Privileged installer listener is running")
        RunLoop.current.run()
    }

    func listener(_: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        log.info("Received new XPC connection request (pid: \(newConnection.processIdentifier))")

        guard isAllowedClient(connection: newConnection) else {
            log.warn("Rejected XPC connection (pid: \(newConnection.processIdentifier))")
            return false
        }

        newConnection.exportedInterface = NSXPCInterface(with: PrivilegedInstallerProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        log.success("Accepted XPC connection (pid: \(newConnection.processIdentifier))")

        return true
    }

    private func isAllowedClient(connection: NSXPCConnection) -> Bool {
        let pid = connection.processIdentifier
        guard pid > 0 else {
            log.warn("Rejecting client with invalid pid: \(pid)")
            return false
        }

        guard let app = NSRunningApplication(processIdentifier: pid_t(pid)),
              app.bundleIdentifier == PrivilegedInstallerConstants.appBundleIdentifier else {
            log.warn("Rejecting client pid \(pid) due to bundle identifier mismatch")
            return false
        }

        return validateCodeSignature(forProcessID: pid_t(pid))
    }

    private func validateCodeSignature(forProcessID pid: pid_t) -> Bool {
        var code: SecCode?
        let attributes = [kSecGuestAttributePid as String: pid] as CFDictionary
        let guestStatus = SecCodeCopyGuestWithAttributes(nil, attributes, SecCSFlags(), &code)

        guard guestStatus == errSecSuccess, let code else {
            log.error("Failed to copy guest code for pid \(pid), status \(guestStatus)")
            return false
        }

        var requirement: SecRequirement?
        let requirementStatus = SecRequirementCreateWithString(
            PrivilegedInstallerConstants.authorizedClientRequirement as CFString,
            SecCSFlags(),
            &requirement
        )

        guard requirementStatus == errSecSuccess, let requirement else {
            log.error("Failed creating requirement, status \(requirementStatus)")
            return false
        }

        let validationStatus = SecCodeCheckValidity(code, SecCSFlags(), requirement)
        guard validationStatus == errSecSuccess else {
            log.error("Code signature requirement check failed for pid \(pid), status \(validationStatus)")
            return false
        }

        log.success("Code signature requirement check passed for pid \(pid)")
        return true
    }

    func atomicSwap(
        _ currentURL: URL,
        stagedURL: URL,
        backupURL: URL,
        withReply reply: @escaping (NSError?) -> ()
    ) {
        Task {
            do {
                try await performAtomicSwap(currentURL: currentURL, stagedURL: stagedURL, backupURL: backupURL)
                reply(nil)
            } catch {
                log.error("Privileged atomic swap failed: \(error.localizedDescription)")
                reply(error as NSError)
            }
        }
    }

    func restoreFromBackup(
        _ currentURL: URL,
        backupURL: URL,
        withReply reply: @escaping (NSError?) -> ()
    ) {
        Task {
            do {
                try await performRestoreFromBackup(currentURL: currentURL, backupURL: backupURL)
                reply(nil)
            } catch {
                log.error("Privileged restore failed: \(error.localizedDescription)")
                reply(error as NSError)
            }
        }
    }

    func removeItem(_ itemURL: URL, withReply reply: @escaping (NSError?) -> ()) {
        Task {
            do {
                try await performRemoveItem(itemURL)
                reply(nil)
            } catch {
                log.error("Privileged remove item failed: \(error.localizedDescription)")
                reply(error as NSError)
            }
        }
    }

    private func performAtomicSwap(currentURL: URL, stagedURL: URL, backupURL: URL) async throws {
        log.info("Starting privileged atomic swap")
        log.info("Current app: \(currentURL.path)")
        log.info("Staged app: \(stagedURL.path)")
        log.info("Backup app: \(backupURL.path)")

        let stagedOwnership = try ownership(for: stagedURL)
        log.success("Resolved staged ownership (uid: \(stagedOwnership.uid), gid: \(stagedOwnership.gid))")

        let backupParent = backupURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: backupParent, withIntermediateDirectories: true)
        log.success("Backup directory ready at \(backupParent.path)")

        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
            log.success("Removed existing backup at \(backupURL.path)")
        }

        try fileManager.moveItem(at: currentURL, to: backupURL)
        log.success("Moved current app to backup location")
        try applyOwnershipRecursively(at: backupURL, uid: stagedOwnership.uid, gid: stagedOwnership.gid)
        log.success("Applied staged ownership to backup")

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

    private func performRestoreFromBackup(currentURL: URL, backupURL: URL) async throws {
        log.info("Starting privileged restore from backup")
        log.info("Current app: \(currentURL.path)")
        log.info("Backup app: \(backupURL.path)")

        guard fileManager.fileExists(atPath: backupURL.path) else {
            log.info("No backup found at \(backupURL.path); restore is a no-op")
            return
        }

        if fileManager.fileExists(atPath: currentURL.path) {
            try fileManager.removeItem(at: currentURL)
            log.success("Removed current app before restore")
        }

        try fileManager.moveItem(at: backupURL, to: currentURL)
        try applyRootOwnershipRecursively(at: currentURL)
        log.success("Privileged restore completed")
    }

    private func performRemoveItem(_ itemURL: URL) async throws {
        log.info("Starting privileged remove item for \(itemURL.path)")

        if fileManager.fileExists(atPath: itemURL.path) {
            try fileManager.removeItem(at: itemURL)
            log.success("Removed item at \(itemURL.path)")
        } else {
            log.info("Item not found at \(itemURL.path); remove is a no-op")
        }

        log.success("Privileged remove item completed")
    }

    private func ownership(for url: URL) throws -> PathOwnership {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)

        guard let ownerID = attributes[.ownerAccountID] as? NSNumber,
              let groupID = attributes[.groupOwnerAccountID] as? NSNumber else {
            throw PrivilegedInstallerError.ownershipLookupFailed(url: url)
        }

        return PathOwnership(uid: uid_t(ownerID.uint32Value), gid: gid_t(groupID.uint32Value))
    }

    private func applyRootOwnershipRecursively(at url: URL) throws {
        log.info("Applying root ownership recursively at \(url.path)")
        try applyOwnershipRecursively(at: url, uid: 0, gid: 0)
        log.success("Applied root ownership recursively at \(url.path)")
    }

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
