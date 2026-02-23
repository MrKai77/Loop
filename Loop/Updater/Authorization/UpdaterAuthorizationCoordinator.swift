import Foundation
import Security
import ServiceManagement
import Scribe

@Loggable
final class UpdaterAuthorizationCoordinator {
    final class PrivilegedSession {
        private unowned let coordinator: UpdaterAuthorizationCoordinator
        private let serviceName: String

        fileprivate init(coordinator: UpdaterAuthorizationCoordinator, serviceName: String) {
            self.coordinator = coordinator
            self.serviceName = serviceName
        }

        func atomicSwap(current: URL, staged: URL, backup: URL) async throws {
            let operation = try coordinator.makeAtomicSwapOperation(
                current: current,
                staged: staged,
                backup: backup
            )
            try await coordinator.performXPCOperation(serviceName: serviceName, operation: operation)
        }

        func restoreFromBackup(current: URL, backup: URL) async throws {
            let operation = try coordinator.makeRestoreOperation(current: current, backup: backup)
            try await coordinator.performXPCOperation(serviceName: serviceName, operation: operation)
        }

        func removeItem(_ path: URL) async throws {
            let operation = try coordinator.makeRemoveItemOperation(path: path)
            try await coordinator.performXPCOperation(serviceName: serviceName, operation: operation)
        }
    }

    private actor ContinuationCompletion {
        private var didComplete = false

        func tryComplete() -> Bool {
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

    func withPrivilegedSession<T>(
        _ body: (PrivilegedSession) async throws -> T
    ) async throws -> T {
        let helperPath = try helperExecutablePath()

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
        let jobDictionary = makeJobDictionary(serviceName: serviceName, helperPath: helperPath)

        try submit(jobDictionary, authRef: authRef)
        defer {
            removeSubmittedJob(serviceName: serviceName, authRef: authRef)
        }

        // Give launchd a brief moment to bootstrap the helper listener.
        try await Task.sleep(for: .milliseconds(250))

        let session = PrivilegedSession(coordinator: self, serviceName: serviceName)
        return try await body(session)
    }

    func performPrivilegedAtomicSwap(current: URL, staged: URL, backup: URL) async throws {
        try await withPrivilegedSession { session in
            try await session.atomicSwap(current: current, staged: staged, backup: backup)
        }
    }

    func performPrivilegedRestore(current: URL, backup: URL) async throws {
        try await withPrivilegedSession { session in
            try await session.restoreFromBackup(current: current, backup: backup)
        }
    }

    func performPrivilegedRemoveItem(_ path: URL) async throws {
        try await withPrivilegedSession { session in
            try await session.removeItem(path)
        }
    }

    private func performXPCOperation(serviceName: String, operation: PrivilegedOperation) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let completion = ContinuationCompletion()
            let finish: @Sendable (Result<Void, Error>) -> Void = { result in
                Task {
                    guard await completion.tryComplete() else { return }
                    switch result {
                    case .success:
                        continuation.resume(returning: ())
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }

            let connection = NSXPCConnection(machServiceName: serviceName, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: PrivilegedInstallerProtocol.self)
            connection.interruptionHandler = {
                finish(.failure(UpdateError.installationFailed("Privileged installer \(operation.name) interrupted")))
            }
            connection.invalidationHandler = {
                finish(.failure(UpdateError.installationFailed("Privileged installer \(operation.name) invalidated")))
            }

            connection.resume()

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                finish(.failure(UpdateError.installationFailed("Privileged installer \(operation.name) transport failed: \(error.localizedDescription)")))
            }) as? PrivilegedInstallerProtocol else {
                connection.invalidate()
                finish(.failure(UpdateError.installationFailed("Failed to connect to privileged installer helper")))
                return
            }

            operation.invoke(on: proxy) { error in
                if let error {
                    finish(.failure(UpdateError.installationFailed(error.localizedDescription)))
                } else {
                    finish(.success(()))
                }
                connection.invalidate()
            }

            Task {
                try await Task.sleep(for: self.operationTimeout)
                finish(.failure(UpdateError.installationFailed("Privileged installer \(operation.name) timed out")))
                connection.invalidate()
            }
        }
    }

    private func helperExecutablePath() throws -> String {
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchServices", isDirectory: true)
            .appendingPathComponent(PrivilegedInstallerConstants.helperExecutableName, isDirectory: false)

        let path = canonicalPath(for: helperURL)

        guard fileManager.fileExists(atPath: path) else {
            throw UpdateError.installationFailed("Privileged installer executable was not found at \(path)")
        }

        guard fileManager.isExecutableFile(atPath: path) else {
            throw UpdateError.installationFailed("Privileged installer executable is not executable at \(path)")
        }

        return path
    }

    private func requestInstallerAuthorizationRight(_ authRef: AuthorizationRef) throws {
        let rightName = installerAuthorizationRightName()
        let prompt = installerAuthorizationPrompt()

        let getStatus = rightName.withCString { AuthorizationRightGet($0, nil) }
        if getStatus == errAuthorizationDenied {
            let setStatus = rightName.withCString { rightNameCString in
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

    private func installerAuthorizationPrompt() -> String {
        "\(Bundle.main.appName) needs administrator permission to install this update."
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

    private func makeAtomicSwapOperation(current: URL, staged: URL, backup: URL) throws -> PrivilegedOperation {
        let currentPath = canonicalPath(for: current)
        let stagedPath = canonicalPath(for: staged)
        let backupPath = canonicalPath(for: backup)

        try validateCurrentBundlePath(currentPath, pathRole: .currentAppBundle)
        try validateLoopSupportPath(stagedPath, pathRole: .stagedBundle)
        try validateLoopSupportPath(backupPath, pathRole: .backupBundle)

        let backupDirectory = URL(fileURLWithPath: backupPath).deletingLastPathComponent()
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        return .atomicSwap(currentPath: currentPath, stagedPath: stagedPath, backupPath: backupPath)
    }

    private func makeRestoreOperation(current: URL, backup: URL) throws -> PrivilegedOperation {
        let currentPath = canonicalPath(for: current)
        let backupPath = canonicalPath(for: backup)

        try validateCurrentBundlePath(currentPath, pathRole: .currentAppBundle)
        try validateLoopSupportPath(backupPath, pathRole: .backupBundle)

        return .restore(currentPath: currentPath, backupPath: backupPath)
    }

    private func makeRemoveItemOperation(path: URL) throws -> PrivilegedOperation {
        let itemPath = canonicalPath(for: path)
        try validateLoopSupportPath(itemPath, pathRole: .cleanupTarget)
        return .removeItem(path: itemPath)
    }

    private func canonicalPath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private var currentBundlePath: String {
        canonicalPath(for: Bundle.main.bundleURL)
    }

    private var loopSupportPath: String {
        canonicalPath(for: SystemPaths.loopDirectory)
    }

    private func validateCurrentBundlePath(_ path: String, pathRole: PrivilegedPathRole) throws {
        guard path == currentBundlePath else {
            throw UpdateError.installationFailed(
                "Privileged installer \(pathRole.description) must match current app path. Received: \(path)"
            )
        }
    }

    private func validateLoopSupportPath(_ path: String, pathRole: PrivilegedPathRole) throws {
        guard isPath(path, inside: loopSupportPath) else {
            throw UpdateError.installationFailed(
                "Privileged installer \(pathRole.description) must be inside Loop support directory. Received: \(path)"
            )
        }
    }

    private func isPath(_ path: String, inside root: String) -> Bool {
        path == root || path.hasPrefix("\(root)/")
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
    case atomicSwap(currentPath: String, stagedPath: String, backupPath: String)
    case restore(currentPath: String, backupPath: String)
    case removeItem(path: String)

    var name: String {
        switch self {
        case .atomicSwap:
            return "atomic swap"
        case .restore:
            return "restore"
        case .removeItem:
            return "remove item"
        }
    }

    func invoke(on proxy: PrivilegedInstallerProtocol, reply: @escaping (NSError?) -> Void) {
        switch self {
        case let .atomicSwap(currentPath, stagedPath, backupPath):
            proxy.atomicSwap(
                currentPath,
                stagedPath: stagedPath,
                backupPath: backupPath,
                withReply: reply
            )

        case let .restore(currentPath, backupPath):
            proxy.restoreFromBackup(
                currentPath,
                backupPath: backupPath,
                withReply: reply
            )

        case let .removeItem(path):
            proxy.removeItem(path, withReply: reply)
        }
    }
}

private enum PrivilegedPathRole {
    case currentAppBundle
    case stagedBundle
    case backupBundle
    case cleanupTarget

    var description: String {
        switch self {
        case .currentAppBundle:
            return "current app bundle path"
        case .stagedBundle:
            return "staged bundle path"
        case .backupBundle:
            return "backup bundle path"
        case .cleanupTarget:
            return "cleanup target path"
        }
    }
}
