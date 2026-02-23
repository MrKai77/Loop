import Foundation
import Scribe

@Loggable
final class PrivilegedInstallerClient {
    private let machServiceName: String

    init(machServiceName: String = PrivilegedInstallerConstants.helperLabel) {
        self.machServiceName = machServiceName
    }

    func prepareBackup(at backupDirectory: URL) async throws {
        try validatePath(backupDirectory)
        let (connection, proxy) = try makeConnectionProxy()

        try await withCheckedThrowingContinuation { continuation in
            proxy.prepareBackup(backupDirectory.standardizedFileURL.path) { error in
                connection.invalidate()
                if let error {
                    continuation.resume(throwing: UpdateError.installationFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func atomicSwap(current: URL, staged: URL, backup: URL) async throws {
        try validatePath(current)
        try validatePath(staged)
        try validatePath(backup)

        let (connection, proxy) = try makeConnectionProxy()

        try await withCheckedThrowingContinuation { continuation in
            proxy.atomicSwap(
                current.standardizedFileURL.path,
                stagedPath: staged.standardizedFileURL.path,
                backupPath: backup.standardizedFileURL.path
            ) { error in
                connection.invalidate()
                if let error {
                    continuation.resume(throwing: UpdateError.installationFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func removeItem(at url: URL) async throws {
        try validatePath(url)
        let (connection, proxy) = try makeConnectionProxy()

        try await withCheckedThrowingContinuation { continuation in
            proxy.removeItem(url.standardizedFileURL.path) { error in
                connection.invalidate()
                if let error {
                    continuation.resume(throwing: UpdateError.installationFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func makeConnectionProxy() throws -> (NSXPCConnection, PrivilegedInstallerProtocol) {
        let connection = NSXPCConnection(machServiceName: machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: PrivilegedInstallerProtocol.self)
        connection.resume()

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
            Self.log.error("XPC communication failed: \(error.localizedDescription)")
        }) as? PrivilegedInstallerProtocol else {
            connection.invalidate()
            throw UpdateError.installationFailed("Failed to connect to privileged installer helper")
        }

        return (connection, proxy)
    }

    private func validatePath(_ url: URL) throws {
        let path = url.standardizedFileURL.path

        if path.hasPrefix("/Applications/") || path == "/Applications" {
            return
        }

        if path.hasPrefix(SystemPaths.loopDirectory.standardizedFileURL.path) {
            return
        }

        let homeRoot = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        if path.hasPrefix("\(homeRoot)/Applications/") || path == "\(homeRoot)/Applications" {
            return
        }

        throw UpdateError.installationFailed("Path is outside allowed privileged installer roots: \(path)")
    }
}
