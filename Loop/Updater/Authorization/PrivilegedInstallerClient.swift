import Foundation
import Scribe

@Loggable
final class PrivilegedInstallerClient {
    private final class ContinuationCompletion {
        private let lock = NSLock()
        private var didComplete = false

        func runOnce(_ block: () -> Void) {
            lock.lock()
            guard !didComplete else {
                lock.unlock()
                return
            }

            didComplete = true
            lock.unlock()
            block()
        }
    }

    private let machServiceName: String

    init(machServiceName: String = PrivilegedInstallerConstants.helperLabel) {
        self.machServiceName = machServiceName
    }

    func prepareBackup(at backupDirectory: URL) async throws {
        try validateLoopSupportPath(backupDirectory, argumentName: "backupDirectory")
        let backupPath = canonicalPath(for: backupDirectory)
        try await performXPCOperation(operationName: "prepareBackup") { proxy, reply in
            proxy.prepareBackup(backupPath, withReply: reply)
        }
    }

    func atomicSwap(current: URL, staged: URL, backup: URL) async throws {
        try validateCurrentBundlePath(current, argumentName: "current")
        try validateLoopSupportPath(staged, argumentName: "staged")
        try validateLoopSupportPath(backup, argumentName: "backup")
        let currentPath = canonicalPath(for: current)
        let stagedPath = canonicalPath(for: staged)
        let backupPath = canonicalPath(for: backup)

        try await performXPCOperation(operationName: "atomicSwap") { proxy, reply in
            proxy.atomicSwap(
                currentPath,
                stagedPath: stagedPath,
                backupPath: backupPath,
                withReply: reply
            )
        }
    }

    func removeItem(at url: URL) async throws {
        let path = canonicalPath(for: url)
        if path != currentBundlePath {
            try validateLoopSupportPath(url, argumentName: "path")
        }

        try await performXPCOperation(operationName: "removeItem") { proxy, reply in
            proxy.removeItem(path, withReply: reply)
        }
    }

    func restoreFromBackup(current: URL, backup: URL) async throws {
        try validateCurrentBundlePath(current, argumentName: "current")
        try validateLoopSupportPath(backup, argumentName: "backup")
        let currentPath = canonicalPath(for: current)
        let backupPath = canonicalPath(for: backup)

        try await performXPCOperation(operationName: "restoreFromBackup") { proxy, reply in
            proxy.restoreFromBackup(
                currentPath,
                backupPath: backupPath,
                withReply: reply
            )
        }
    }

    private func performXPCOperation(
        operationName: String,
        invoke: @escaping (PrivilegedInstallerProtocol, @escaping (NSError?) -> Void) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let completion = ContinuationCompletion()
            let finish: (Result<Void, Error>) -> Void = { result in
                completion.runOnce {
                    switch result {
                    case .success:
                        continuation.resume(returning: ())
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }
            }

            do {
                let (connection, proxy) = try makeConnectionProxy(operationName: operationName) { error in
                    finish(.failure(UpdateError.installationFailed("Privileged installer \(operationName) transport failed: \(error.localizedDescription)")))
                }

                connection.interruptionHandler = {
                    finish(.failure(UpdateError.installationFailed("Privileged installer \(operationName) interrupted")))
                }

                connection.invalidationHandler = {
                    finish(.failure(UpdateError.installationFailed("Privileged installer \(operationName) invalidated")))
                }

                invoke(proxy) { error in
                    if let error {
                        finish(.failure(UpdateError.installationFailed(error.localizedDescription)))
                    } else {
                        finish(.success(()))
                    }
                    connection.invalidate()
                }
            } catch {
                finish(.failure(error))
            }
        }
    }

    private func makeConnectionProxy(
        operationName: String,
        onTransportError: @escaping (Error) -> Void
    ) throws -> (NSXPCConnection, PrivilegedInstallerProtocol) {
        let connection = NSXPCConnection(machServiceName: machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: PrivilegedInstallerProtocol.self)
        connection.resume()
        let logger = log

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            logger.error("XPC communication failed (\(operationName)): \(error.localizedDescription)")
            onTransportError(error)
        }) as? PrivilegedInstallerProtocol else {
            connection.invalidate()
            throw UpdateError.installationFailed("Failed to connect to privileged installer helper")
        }

        return (connection, proxy)
    }

    private var currentBundlePath: String {
        canonicalPath(for: Bundle.main.bundleURL)
    }

    private var loopSupportPath: String {
        canonicalPath(for: SystemPaths.loopDirectory)
    }

    private func canonicalPath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func validateCurrentBundlePath(_ url: URL, argumentName: String) throws {
        let path = canonicalPath(for: url)
        guard path == currentBundlePath else {
            throw UpdateError.installationFailed(
                "Privileged installer \(argumentName) must match current app path. Received: \(path)"
            )
        }
    }

    private func validateLoopSupportPath(_ url: URL, argumentName: String) throws {
        let path = canonicalPath(for: url)
        guard isPath(path, inside: loopSupportPath) else {
            throw UpdateError.installationFailed(
                "Privileged installer \(argumentName) must be inside Loop support directory. Received: \(path)"
            )
        }
    }

    private func isPath(_ path: String, inside root: String) -> Bool {
        path == root || path.hasPrefix("\(root)/")
    }
}
