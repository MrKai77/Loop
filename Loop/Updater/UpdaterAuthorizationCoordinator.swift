//
//  UpdaterAuthorizationCoordinator.swift
//  Loop
//
//  Created by Kai Azim on 2026-02-23.
//

import Foundation
import Scribe
import Security
import ServiceManagement

@Loggable
final class UpdaterAuthorizationCoordinator {
    enum PrivilegedHelperReadiness: Sendable {
        case available
        case unavailable(reason: String)
    }

    final class PrivilegedSession {
        private unowned let coordinator: UpdaterAuthorizationCoordinator
        private let connection: NSXPCConnection

        fileprivate init(coordinator: UpdaterAuthorizationCoordinator, connection: NSXPCConnection) {
            self.coordinator = coordinator
            self.connection = connection
        }

        /// Invokes the helper atomic swap using a rollback token instead of caller-provided paths.
        func atomicSwap(rollbackID: String) async throws {
            let operation = PrivilegedOperation.atomicSwap(rollbackID: rollbackID)
            try await coordinator.performXPCOperation(connection: connection, operation: operation)
        }

        /// Invokes helper restore for the rollback token selected by the caller.
        func restoreFromBackup(rollbackID: String) async throws {
            let operation = PrivilegedOperation.restore(rollbackID: rollbackID)
            try await coordinator.performXPCOperation(connection: connection, operation: operation)
        }

        /// Removes the authenticated client's current app bundle.
        func removeCurrentBundle() async throws {
            let operation = PrivilegedOperation.removeCurrentBundle
            try await coordinator.performXPCOperation(connection: connection, operation: operation)
        }
    }

    private final class ContinuationCompletion: @unchecked Sendable {
        private let lock = NSLock()
        private var didComplete = false

        func tryComplete() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard !didComplete else { return false }
            didComplete = true
            return true
        }
    }

    private let fileManager: FileManager

    private let operationTimeout: Duration = .seconds(90)

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func privilegedHelperReadiness() -> PrivilegedHelperReadiness {
        do {
            _ = try helperExecutableURL()
            return .available
        } catch {
            return .unavailable(reason: error.localizedDescription)
        }
    }

    func withPrivilegedSession<T>(
        _ body: (PrivilegedSession) async throws -> T
    ) async throws -> T {
        let helperURL = try helperExecutableURL()

        var authRef: AuthorizationRef?
        let createStatus = AuthorizationCreate(nil, nil, [], &authRef)

        guard createStatus == errAuthorizationSuccess, let authRef else {
            throw UpdateError.installationFailed(
                "Could not request installation authorization: \(authorizationErrorMessage(for: createStatus))"
            )
        }

        defer {
            AuthorizationFree(authRef, [.destroyRights])
        }

        try requestInstallerAuthorizationRight(authRef)

        let serviceName = PrivilegedInstallerConstants.serviceName
        let jobDictionary = makeJobDictionary(serviceName: serviceName, helperPath: helperURL.path)

        try submit(jobDictionary, authRef: authRef)
        defer {
            removeSubmittedJob(serviceName: serviceName, authRef: authRef)
        }

        // Give launchd a brief moment to bootstrap the helper listener.
        try await Task.sleep(for: .milliseconds(250))

        let connection = NSXPCConnection(machServiceName: serviceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: PrivilegedInstallerProtocol.self)
        connection.resume()

        defer {
            connection.invalidationHandler = nil
            connection.interruptionHandler = nil
            connection.invalidate()
        }

        let session = PrivilegedSession(coordinator: self, connection: connection)
        return try await body(session)
    }

    private func performXPCOperation(connection: NSXPCConnection, operation: PrivilegedOperation) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let completion = ContinuationCompletion()
            var timeoutTask: Task<(), Never>?

            // Keep completion synchronous so competing callbacks cannot resume more than once.
            let finish: (Result<(), Error>) -> () = { result in
                guard completion.tryComplete() else { return }
                timeoutTask?.cancel()
                connection.interruptionHandler = nil
                connection.invalidationHandler = nil
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }

            connection.interruptionHandler = {
                self.log.warn("Privileged installer \(operation.name) interrupted during shared session")
                finish(.failure(UpdateError.installationFailed("Privileged installer \(operation.name) interrupted")))
            }
            connection.invalidationHandler = {
                self.log.warn("Privileged installer \(operation.name) invalidated during shared session")
                finish(.failure(UpdateError.installationFailed("Privileged installer \(operation.name) invalidated")))
            }

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                self.log.warn("Privileged installer \(operation.name) transport failed during shared session: \(error.localizedDescription)")
                finish(.failure(UpdateError.installationFailed("Privileged installer \(operation.name) transport failed: \(error.localizedDescription)")))
            }) as? PrivilegedInstallerProtocol else {
                self.log.warn("Failed to connect to privileged installer helper for \(operation.name)")
                finish(.failure(UpdateError.installationFailed("Failed to connect to privileged installer helper")))
                return
            }

            // NSXPC reports remote failures via callbacks; direct throwing proxy calls can raise uncaught Objective-C exceptions.
            operation.invoke(on: proxy) { error in
                if let error {
                    finish(.failure(UpdateError.installationFailed(error.localizedDescription)))
                } else {
                    finish(.success(()))
                }
            }

            timeoutTask = Task {
                do {
                    try await Task.sleep(for: self.operationTimeout)
                } catch {
                    return
                }

                self.log.warn("Privileged installer \(operation.name) timed out during shared session")
                finish(.failure(UpdateError.installationFailed("Privileged installer \(operation.name) timed out")))
            }
        }
    }

    private func helperExecutableURL() throws -> URL {
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchServices", isDirectory: true)
            .appendingPathComponent(PrivilegedInstallerConstants.helperExecutableName, isDirectory: false)

        let canonicalHelperURL = helperURL.resolvingSymlinksInPath().standardizedFileURL
        let helperPath = canonicalHelperURL.path

        guard fileManager.fileExists(atPath: helperPath) else {
            throw UpdateError.installationFailed("Privileged installer executable was not found at \(helperPath)")
        }

        guard fileManager.isExecutableFile(atPath: helperPath) else {
            throw UpdateError.installationFailed("Privileged installer executable is not executable at \(helperPath)")
        }

        return canonicalHelperURL
    }

    private func requestInstallerAuthorizationRight(_ authRef: AuthorizationRef) throws {
        let rightName = installerAuthorizationRightName()
        let prompt = "\(Bundle.main.appName) needs administrator permission to install this update."

        let getStatus = rightName.withCString { AuthorizationRightGet($0, nil) }
        if getStatus == errAuthorizationDenied {
            let setStatus = rightName.withCString { rightNameCString in
                // Mirrors Sparkle's code. If kSMRightModifySystemDaemons is added,
                // the permission prompt changes, seems to change the wording.
                AuthorizationRightSet(
                    authRef,
                    rightNameCString,
                    kAuthorizationRuleAuthenticateAsAdmin as CFTypeRef,
                    prompt as CFString,
                    nil,
                    nil
                )
            }

            if setStatus != errAuthorizationSuccess {
                log.warn("Failed to set installer authorization right \(rightName): \(authorizationErrorMessage(for: setStatus))")
            }
        } else if getStatus != errAuthorizationSuccess {
            log.warn("Failed to retrieve installer authorization right \(rightName): \(authorizationErrorMessage(for: getStatus))")
        }

        let rightsStatus: OSStatus = rightName.withCString { rightNameCString in
            var requestedRight = AuthorizationItem(
                name: rightNameCString,
                valueLength: 0,
                value: nil,
                flags: 0
            )

            return withUnsafeMutablePointer(to: &requestedRight) { rightPtr in
                var requestedRights = AuthorizationRights(count: 1, items: rightPtr)
                return AuthorizationCopyRights(
                    authRef,
                    &requestedRights,
                    nil,
                    [.interactionAllowed, .extendRights],
                    nil
                )
            }
        }

        guard rightsStatus == errAuthorizationSuccess else {
            throw UpdateError.installationFailed(
                "Authorization rights request failed: \(authorizationErrorMessage(for: rightsStatus))"
            )
        }

        log.info("Authorization rights granted for one-shot privileged installer")
    }

    private func installerAuthorizationRightName() -> String {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.MrKai77.Loop"
        return "\(bundleIdentifier).updater-auth"
    }

    private func makeJobDictionary(serviceName: String, helperPath: String) -> [String: Any] {
        [
            "Label": serviceName,
            "ProgramArguments": [
                helperPath
            ],
            "MachServices": [
                serviceName: true
            ],
            "RunAtLoad": true,
            "LaunchOnlyOnce": true
        ]
    }

    private func submit(_ jobDictionary: [String: Any], authRef: AuthorizationRef) throws {
        var error: Unmanaged<CFError>?
        let success = SMJobSubmit(
            kSMDomainSystemLaunchd,
            jobDictionary as CFDictionary,
            authRef,
            &error
        )

        guard success else {
            let details = error?.takeRetainedValue().localizedDescription ?? "Unknown privileged submission failure"
            throw UpdateError.installationFailed("Privileged installer submission failed: \(details)")
        }
    }

    private func removeSubmittedJob(serviceName: String, authRef: AuthorizationRef) {
        var error: Unmanaged<CFError>?
        let removed = SMJobRemove(
            kSMDomainSystemLaunchd,
            serviceName as CFString,
            authRef,
            true,
            &error
        )

        guard !removed else {
            return
        }

        let details = error?.takeRetainedValue().localizedDescription ?? "Unknown cleanup failure"
        log.warn("Failed to remove privileged updater job \(serviceName): \(details)")
    }

    private func authorizationErrorMessage(for status: OSStatus) -> String {
        if status == errAuthorizationCanceled {
            return "User canceled administrator authorization (OSStatus \(status))"
        }

        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return "\(message) (OSStatus \(status))"
        }

        return "OSStatus \(status)"
    }
}

private enum PrivilegedOperation {
    case atomicSwap(rollbackID: String)
    case restore(rollbackID: String)
    case removeCurrentBundle

    var name: String {
        switch self {
        case .atomicSwap:
            "atomic swap"
        case .restore:
            "restore"
        case .removeCurrentBundle:
            "remove current bundle"
        }
    }

    /// Dispatches the selected privileged operation on the typed helper proxy.
    func invoke(on proxy: PrivilegedInstallerProtocol, reply: @escaping (NSError?) -> ()) {
        switch self {
        case let .atomicSwap(rollbackID):
            proxy.atomicSwap(rollbackID: rollbackID, withReply: reply)
        case let .restore(rollbackID):
            proxy.restoreFromBackup(rollbackID: rollbackID, withReply: reply)
        case .removeCurrentBundle:
            proxy.removeCurrentBundle(withReply: reply)
        }
    }
}
