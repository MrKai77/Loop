import Foundation
import Security
import ServiceManagement
import Scribe

@Loggable
final class UpdaterAuthorizationCoordinator {
    private let client: PrivilegedInstallerClient

    init(client: PrivilegedInstallerClient = .init()) {
        self.client = client
    }

    func performPrivilegedAtomicSwap(current: URL, staged: URL, backup: URL) async throws {
        try authorizeAndBlessHelper()
        try await client.prepareBackup(at: backup.deletingLastPathComponent())
        try await client.atomicSwap(current: current, staged: staged, backup: backup)
    }

    private func authorizeAndBlessHelper() throws {
        var authRef: AuthorizationRef?
        let createStatus = AuthorizationCreate(nil, nil, [.interactionAllowed, .extendRights, .preAuthorize], &authRef)

        guard createStatus == errAuthorizationSuccess, let authRef else {
            throw UpdateError.installationFailed("Could not request installation authorization (OSStatus \(createStatus))")
        }

        defer {
            AuthorizationFree(authRef, [.destroyRights])
        }

        var error: Unmanaged<CFError>?
        let success = SMJobBless(kSMDomainSystemLaunchd, PrivilegedInstallerConstants.helperLabel as CFString, authRef, &error)

        guard success else {
            let details = error?.takeRetainedValue().localizedDescription ?? "Unknown authorization failure"
            throw UpdateError.installationFailed("Authorization failed: \(details)")
        }

        log.info("Privileged helper authorization succeeded")
    }
}
