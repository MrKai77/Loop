import AppKit
import Darwin
import Foundation
import Security

final class PrivilegedInstallerService: NSObject, NSXPCListenerDelegate, PrivilegedInstallerProtocol {
    private struct PathOwnership {
        let uid: uid_t
        let gid: gid_t
    }

    private let listener: NSXPCListener
    private let fileManager = FileManager.default

    init(serviceName: String) {
        listener = NSXPCListener(machServiceName: serviceName)
        super.init()
        listener.delegate = self
    }

    func run() {
        listener.resume()
        RunLoop.current.run()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard isAllowedClient(connection: newConnection) else {
            return false
        }

        newConnection.exportedInterface = NSXPCInterface(with: PrivilegedInstallerProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()

        return true
    }

    private func isAllowedClient(connection: NSXPCConnection) -> Bool {
        let pid = connection.processIdentifier
        guard pid > 0 else {
            return false
        }

        guard let app = NSRunningApplication(processIdentifier: pid_t(pid)),
              app.bundleIdentifier == PrivilegedInstallerConstants.appBundleIdentifier else {
            return false
        }

        return validateCodeSignature(forProcessID: pid_t(pid))
    }

    private func validateCodeSignature(forProcessID pid: pid_t) -> Bool {
        var code: SecCode?
        let attributes = [kSecGuestAttributePid as String: pid] as CFDictionary
        let guestStatus = SecCodeCopyGuestWithAttributes(nil, attributes, SecCSFlags(), &code)

        guard guestStatus == errSecSuccess, let code else {
            NSLog("LoopUpdaterHelper: Failed to copy guest code for pid \(pid), status \(guestStatus)")
            return false
        }

        var requirement: SecRequirement?
        let requirementStatus = SecRequirementCreateWithString(
            PrivilegedInstallerConstants.authorizedClientRequirement as CFString,
            SecCSFlags(),
            &requirement
        )

        guard requirementStatus == errSecSuccess, let requirement else {
            NSLog("LoopUpdaterHelper: Failed creating requirement, status \(requirementStatus)")
            return false
        }

        let validationStatus = SecCodeCheckValidity(code, SecCSFlags(), requirement)
        guard validationStatus == errSecSuccess else {
            NSLog("LoopUpdaterHelper: Code signature requirement check failed for pid \(pid), status \(validationStatus)")
            return false
        }

        return true
    }

    func atomicSwap(
        _ currentPath: String,
        stagedPath: String,
        backupPath: String,
        withReply reply: @escaping (NSError?) -> Void
    ) {
        do {
            let callerBundlePath = try resolveCallerBundlePath()
            let canonicalCurrentPath = canonicalPath(for: currentPath)
            let canonicalStagedPath = canonicalPath(for: stagedPath)
            let canonicalBackupPath = canonicalPath(for: backupPath)

            try requireCallerBundlePath(canonicalCurrentPath, callerBundlePath: callerBundlePath, argumentName: "currentPath")
            try requireLoopSupportPath(canonicalStagedPath, argumentName: "stagedPath")
            try requireLoopSupportPath(canonicalBackupPath, argumentName: "backupPath")

            let currentURL = URL(fileURLWithPath: canonicalCurrentPath)
            let stagedURL = URL(fileURLWithPath: canonicalStagedPath)
            let backupURL = URL(fileURLWithPath: canonicalBackupPath)
            let stagedOwnership = try ownership(for: canonicalStagedPath)

            let backupParent = backupURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: backupParent, withIntermediateDirectories: true)

            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }

            try fileManager.moveItem(at: currentURL, to: backupURL)
            try applyOwnershipRecursively(at: backupURL, uid: stagedOwnership.uid, gid: stagedOwnership.gid)

            do {
                try fileManager.moveItem(at: stagedURL, to: currentURL)
                try applyRootOwnershipRecursively(at: currentURL)
            } catch {
                try? fileManager.removeItem(at: currentURL)
                try? fileManager.moveItem(at: backupURL, to: currentURL)
                try? applyRootOwnershipRecursively(at: currentURL)
                throw error
            }
            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    func restoreFromBackup(
        _ currentPath: String,
        backupPath: String,
        withReply reply: @escaping (NSError?) -> Void
    ) {
        do {
            let callerBundlePath = try resolveCallerBundlePath()
            let canonicalCurrentPath = canonicalPath(for: currentPath)
            let canonicalBackupPath = canonicalPath(for: backupPath)

            try requireCallerBundlePath(canonicalCurrentPath, callerBundlePath: callerBundlePath, argumentName: "currentPath")
            try requireLoopSupportPath(canonicalBackupPath, argumentName: "backupPath")

            let currentURL = URL(fileURLWithPath: canonicalCurrentPath)
            let backupURL = URL(fileURLWithPath: canonicalBackupPath)

            guard fileManager.fileExists(atPath: backupURL.path) else {
                reply(nil)
                return
            }

            if fileManager.fileExists(atPath: currentURL.path) {
                try fileManager.removeItem(at: currentURL)
            }

            try fileManager.moveItem(at: backupURL, to: currentURL)
            try applyRootOwnershipRecursively(at: currentURL)
            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    func removeItem(_ path: String, withReply reply: @escaping (NSError?) -> Void) {
        do {
            let canonicalItemPath = canonicalPath(for: path)
            try requireLoopSupportPath(canonicalItemPath, argumentName: "path")

            let itemURL = URL(fileURLWithPath: canonicalItemPath)
            if fileManager.fileExists(atPath: itemURL.path) {
                try fileManager.removeItem(at: itemURL)
            }

            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    private func resolveCallerBundlePath() throws -> String {
        guard let connection = NSXPCConnection.current() else {
            throw PrivilegedInstallerError.currentConnectionUnavailable
        }

        let pid = connection.processIdentifier
        guard pid > 0 else {
            throw PrivilegedInstallerError.callerProcessIdentifierUnavailable
        }

        guard let app = NSRunningApplication(processIdentifier: pid_t(pid)),
              let bundleURL = app.bundleURL else {
            throw PrivilegedInstallerError.callerBundlePathUnavailable(pid: Int32(pid))
        }

        return canonicalPath(for: bundleURL)
    }

    private func canonicalPath(for rawPath: String) -> String {
        canonicalPath(for: URL(fileURLWithPath: rawPath))
    }

    private func canonicalPath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private var loopSupportPath: String {
        canonicalPath(for: SystemPaths.loopDirectory)
    }

    private func ownership(for path: String) throws -> PathOwnership {
        let attributes = try fileManager.attributesOfItem(atPath: path)

        guard let ownerID = attributes[.ownerAccountID] as? NSNumber,
              let groupID = attributes[.groupOwnerAccountID] as? NSNumber else {
            throw PrivilegedInstallerError.ownershipLookupFailed(path: path)
        }

        return PathOwnership(uid: uid_t(ownerID.uint32Value), gid: gid_t(groupID.uint32Value))
    }

    private func applyRootOwnershipRecursively(at url: URL) throws {
        try applyOwnershipRecursively(at: url, uid: 0, gid: 0)
    }

    private func applyOwnershipRecursively(at rootURL: URL, uid: uid_t, gid: gid_t) throws {
        try applyOwnership(to: rootURL, uid: uid, gid: gid)

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        while let itemURL = enumerator.nextObject() as? URL {
            try applyOwnership(to: itemURL, uid: uid, gid: gid)
        }
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
            throw PrivilegedInstallerError.ownershipChangeFailed(path: itemURL.path, code: errorCode)
        }
    }

    private func requireCallerBundlePath(
        _ path: String,
        callerBundlePath: String,
        argumentName: String
    ) throws {
        guard path == callerBundlePath else {
            throw PrivilegedInstallerError.callerBundlePathMismatch(
                argument: argumentName,
                providedPath: path,
                expectedPath: callerBundlePath
            )
        }
    }

    private func requireLoopSupportPath(_ path: String, argumentName: String) throws {
        guard isLoopSupportPath(path) else {
            throw PrivilegedInstallerError.pathOutsideLoopSupport(argument: argumentName, providedPath: path)
        }
    }

    private func isLoopSupportPath(_ path: String) -> Bool {
        isPath(path, inside: loopSupportPath)
    }

    private func isPath(_ path: String, inside root: String) -> Bool {
        path == root || path.hasPrefix("\(root)/")
    }
}

private enum PrivilegedInstallerError: LocalizedError {
    case currentConnectionUnavailable
    case callerProcessIdentifierUnavailable
    case callerBundlePathUnavailable(pid: Int32)
    case ownershipLookupFailed(path: String)
    case ownershipChangeFailed(path: String, code: Int32)
    case callerBundlePathMismatch(argument: String, providedPath: String, expectedPath: String)
    case pathOutsideLoopSupport(argument: String, providedPath: String)
    
    var errorDescription: String? {
        switch self {
        case .currentConnectionUnavailable:
            return "Unable to resolve current XPC connection"
        case .callerProcessIdentifierUnavailable:
            return "Unable to resolve caller process identifier"
        case let .callerBundlePathUnavailable(pid):
            return "Unable to resolve caller bundle path for pid \(pid)"
        case let .ownershipLookupFailed(path):
            return "Could not resolve ownership for \(path)"
        case let .ownershipChangeFailed(path, code):
            let message = String(cString: strerror(code))
            return "Failed to set ownership for \(path): \(message) (\(code))"
        case let .callerBundlePathMismatch(argument, providedPath, expectedPath):
            return "Refused privileged operation: \(argument) (\(providedPath)) does not match caller bundle path (\(expectedPath))"
        case let .pathOutsideLoopSupport(argument, providedPath):
            return "Refused privileged operation: \(argument) is outside Loop support directory (\(providedPath))"
        }
    }
}

let service = PrivilegedInstallerService(serviceName: PrivilegedInstallerConstants.serviceName)
service.run()
