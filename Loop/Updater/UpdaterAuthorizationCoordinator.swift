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
            // Keep completion synchronous so connection invalidation cannot win the race after success.
            let finish: @Sendable (Result<(), Error>) -> () = { result in
                guard completion.tryComplete() else { return }
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case let .failure(error):
                    continuation.resume(throwing: error)
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
                finish(.failure(UpdateError.installationFailed("Failed to connect to privileged installer helper")))
                connection.invalidate()
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
        let prompt = installerAuthorizationPrompt()

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
        try validateCurrentBundlePath(current, pathRole: .currentAppBundle)
        try validateLoopSupportPath(staged, pathRole: .stagedBundle)
        try validateLoopSupportPath(backup, pathRole: .backupBundle)

        let backupDirectory = backup.deletingLastPathComponent()
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        return .atomicSwap(currentURL: current, stagedURL: staged, backupURL: backup)
    }

    private func makeRestoreOperation(current: URL, backup: URL) throws -> PrivilegedOperation {
        try validateCurrentBundlePath(current, pathRole: .currentAppBundle)
        try validateLoopSupportPath(backup, pathRole: .backupBundle)

        return .restore(currentURL: current, backupURL: backup)
    }

    private func makeRemoveItemOperation(path: URL) throws -> PrivilegedOperation {
        try validateLoopSupportPath(path, pathRole: .cleanupTarget)
        return .removeItem(itemURL: path)
    }

    private var currentBundleURL: URL {
        Bundle.main.bundleURL
    }

    private var loopSupportURL: URL {
        SystemPaths.loopDirectory
    }

    private func validateCurrentBundlePath(_ url: URL, pathRole: PrivilegedPathRole) throws {
        guard SystemPaths.isSamePath(url, currentBundleURL) else {
            throw UpdateError.installationFailed(
                "Privileged installer \(pathRole.description) must match current app path. Received: \(url.path)"
            )
        }
    }

    private func validateLoopSupportPath(_ url: URL, pathRole: PrivilegedPathRole) throws {
        guard SystemPaths.isPath(url, inside: loopSupportURL) else {
            throw UpdateError.installationFailed(
                "Privileged installer \(pathRole.description) must be inside Loop support directory. Received: \(url.path)"
            )
        }
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
    case atomicSwap(currentURL: URL, stagedURL: URL, backupURL: URL)
    case restore(currentURL: URL, backupURL: URL)
    case removeItem(itemURL: URL)

    var name: String {
        switch self {
        case .atomicSwap:
            "atomic swap"
        case .restore:
            "restore"
        case .removeItem:
            "remove item"
        }
    }

    func invoke(on proxy: PrivilegedInstallerProtocol, reply: @escaping (NSError?) -> ()) {
        switch self {
        case let .atomicSwap(currentURL, stagedURL, backupURL):
            proxy.atomicSwap(
                currentURL,
                stagedURL: stagedURL,
                backupURL: backupURL,
                withReply: reply
            )

        case let .restore(currentURL, backupURL):
            proxy.restoreFromBackup(
                currentURL,
                backupURL: backupURL,
                withReply: reply
            )

        case let .removeItem(itemURL):
            proxy.removeItem(itemURL, withReply: reply)
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
            "current app bundle path"
        case .stagedBundle:
            "staged bundle path"
        case .backupBundle:
            "backup bundle path"
        case .cleanupTarget:
            "cleanup target path"
        }
    }
}
