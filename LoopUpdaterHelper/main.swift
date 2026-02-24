import AppKit
import Darwin
import Foundation
import Security
import Scribe

@Loggable
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

        return true
    }

    func atomicSwap(
        _ currentURL: URL,
        stagedURL: URL,
        backupURL: URL,
        withReply reply: @escaping (NSError?) -> Void
    ) {
        do {
            let callerBundleURL = try resolveCallerBundleURL()

            try requireCallerBundlePath(currentURL, callerBundleURL: callerBundleURL, argumentName: "currentURL")
            try requireLoopSupportPath(stagedURL, argumentName: "stagedURL")
            try requireLoopSupportPath(backupURL, argumentName: "backupURL")

            let stagedOwnership = try ownership(for: stagedURL)

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
        _ currentURL: URL,
        backupURL: URL,
        withReply reply: @escaping (NSError?) -> Void
    ) {
        do {
            let callerBundleURL = try resolveCallerBundleURL()

            try requireCallerBundlePath(currentURL, callerBundleURL: callerBundleURL, argumentName: "currentURL")
            try requireLoopSupportPath(backupURL, argumentName: "backupURL")

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

    func removeItem(_ itemURL: URL, withReply reply: @escaping (NSError?) -> Void) {
        do {
            try requireLoopSupportPath(itemURL, argumentName: "itemURL")

            if fileManager.fileExists(atPath: itemURL.path) {
                try fileManager.removeItem(at: itemURL)
            }

            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    private func resolveCallerBundleURL() throws -> URL {
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

        return bundleURL.resolvingSymlinksInPath().standardizedFileURL
    }

    private var loopSupportURL: URL {
        SystemPaths.loopDirectory
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
            throw PrivilegedInstallerError.ownershipChangeFailed(url: itemURL, code: errorCode)
        }
    }

    private func requireCallerBundlePath(
        _ url: URL,
        callerBundleURL: URL,
        argumentName: String
    ) throws {
        guard SystemPaths.isSamePath(url, callerBundleURL) else {
            throw PrivilegedInstallerError.callerBundlePathMismatch(
                argument: argumentName,
                providedURL: url,
                expectedURL: callerBundleURL
            )
        }
    }

    private func requireLoopSupportPath(_ url: URL, argumentName: String) throws {
        guard isLoopSupportPath(url) else {
            throw PrivilegedInstallerError.pathOutsideLoopSupport(argument: argumentName, providedURL: url)
        }
    }

    private func isLoopSupportPath(_ url: URL) -> Bool {
        SystemPaths.isPath(url, inside: loopSupportURL)
    }
}

private enum PrivilegedInstallerError: LocalizedError {
    case currentConnectionUnavailable
    case callerProcessIdentifierUnavailable
    case callerBundlePathUnavailable(pid: Int32)
    case ownershipLookupFailed(url: URL)
    case ownershipChangeFailed(url: URL, code: Int32)
    case callerBundlePathMismatch(argument: String, providedURL: URL, expectedURL: URL)
    case pathOutsideLoopSupport(argument: String, providedURL: URL)
    
    var errorDescription: String? {
        switch self {
        case .currentConnectionUnavailable:
            return "Unable to resolve current XPC connection"
        case .callerProcessIdentifierUnavailable:
            return "Unable to resolve caller process identifier"
        case let .callerBundlePathUnavailable(pid):
            return "Unable to resolve caller bundle path for pid \(pid)"
        case let .ownershipLookupFailed(url):
            return "Could not resolve ownership for \(url.path)"
        case let .ownershipChangeFailed(url, code):
            let message = String(cString: strerror(code))
            return "Failed to set ownership for \(url.path): \(message) (\(code))"
        case let .callerBundlePathMismatch(argument, providedURL, expectedURL):
            return "Refused privileged operation: \(argument) (\(providedURL.path)) does not match caller bundle path (\(expectedURL.path))"
        case let .pathOutsideLoopSupport(argument, providedURL):
            return "Refused privileged operation: \(argument) is outside Loop support directory (\(providedURL.path))"
        }
    }
}

let service = PrivilegedInstallerService(serviceName: PrivilegedInstallerConstants.serviceName)
service.run()
