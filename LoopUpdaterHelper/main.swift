import AppKit
import Foundation
import Security

final class PrivilegedInstallerService: NSObject, NSXPCListenerDelegate, PrivilegedInstallerProtocol {
    private let fileManager = FileManager.default
    private let authorizedClientRequirement = "identifier \"com.MrKai77.Loop\" and anchor apple generic and certificate leaf[subject.OU] = \"5F967GYF84\""

    func run() {
        let listener = NSXPCListener(machServiceName: PrivilegedInstallerConstants.helperLabel)
        listener.delegate = self
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
            authorizedClientRequirement as CFString,
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

    func prepareBackup(_ backupDirectory: String, withReply reply: @escaping (NSError?) -> Void) {
        do {
            try validateAllowedPath(backupDirectory)
            try fileManager.createDirectory(atPath: backupDirectory, withIntermediateDirectories: true, attributes: nil)
            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    func atomicSwap(
        _ currentPath: String,
        stagedPath: String,
        backupPath: String,
        withReply reply: @escaping (NSError?) -> Void
    ) {
        do {
            try validateAllowedPath(currentPath)
            try validateAllowedPath(stagedPath)
            try validateAllowedPath(backupPath)

            let currentURL = URL(fileURLWithPath: currentPath)
            let stagedURL = URL(fileURLWithPath: stagedPath)
            let backupURL = URL(fileURLWithPath: backupPath)

            let backupParent = backupURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: backupParent, withIntermediateDirectories: true)

            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }

            try fileManager.moveItem(at: currentURL, to: backupURL)

            do {
                try fileManager.moveItem(at: stagedURL, to: currentURL)
            } catch {
                try? fileManager.removeItem(at: currentURL)
                try? fileManager.moveItem(at: backupURL, to: currentURL)
                throw error
            }

            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    func removeItem(_ path: String, withReply reply: @escaping (NSError?) -> Void) {
        do {
            try validateAllowedPath(path)
            let url = URL(fileURLWithPath: path)

            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }

            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }

    private func validateAllowedPath(_ rawPath: String) throws {
        let path = URL(fileURLWithPath: rawPath).standardizedFileURL.path

        if path == "/Applications" || path.hasPrefix("/Applications/") {
            return
        }

        let isUserApplications = path.hasPrefix("/Users/") &&
            (path.contains("/Applications/") || path.hasSuffix("/Applications"))
        let isLoopSupport = path.hasPrefix("/Users/") && path.contains("/Library/Application Support/Loop")

        if isUserApplications || isLoopSupport {
            return
        }

        throw NSError(domain: "LoopUpdaterHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Refused privileged operation for disallowed path: \(path)"])
    }
}

PrivilegedInstallerService().run()
