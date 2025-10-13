//
//  AccessibilityManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-04-08.
//

import Defaults
import SwiftUI

/// Stores and manages the accessibility permission state for Loop.
final class AccessibilityManager {
    static let shared: AccessibilityManager = .init()

    private var permissionCheckerTask: Task<(), Never>!
    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
    private(set) var isGranted: Bool

    private init() {
        self.isGranted = Self.getStatus()

        // Setup permission change notification monitoring
        self.permissionCheckerTask = Task {
            let notifications = DistributedNotificationCenter
                .default()
                .notifications(named: .AXPermissionsChanged)

            for await _ in notifications {
                /// It seems like the notification is sent immediately after a state change, sometimes before the actual
                /// reading from `AXIsProcessTrustedWithOptions` is updated.
                /// So sleep for 250 milliseconds (this is generous, but just to ensure that the reading will be correct).
                try? await Task.sleep(for: .milliseconds(250))

                let status = Self.getStatus()
                self.yield(status)
            }
        }
    }

    deinit {
        permissionCheckerTask.cancel()

        let currentContinuations = Array(continuations.values)
        continuations.removeAll()

        for continuation in currentContinuations {
            continuation.finish()
        }
    }

    // MARK: Streaming

    /// Stream new changes to Loop's accessibility permissions.
    /// - Parameter initial: whether to send an initial value corresponding to Loop's current permissions
    /// - Returns: an AsyncStream.
    func stream(initial: Bool = true) -> AsyncStream<Bool> {
        AsyncStream<Bool> { continuation in
            let id = UUID()
            continuations[id] = continuation

            if initial {
                continuation.yield(isGranted)
            }

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                continuations[id] = nil
            }
        }
    }

    /// This will yield a new value to all streams if the provided value differs from the previous value.
    /// - Parameter value: the provided value.
    private func yield(_ value: Bool) {
        guard value != isGranted else { return }

        let currentContinuations = continuations.values

        for continuation in currentContinuations {
            continuation.yield(value)
        }

        isGranted = value
    }

    // MARK: Permissions Checking

    /// Requests accessibility permissions to the user.
    /// - Returns: whether the user granted the permission.
    @discardableResult
    static func requestAccess() -> Bool {
        if getStatus() {
            return true
        }
        resetAccessibility() // In case Loop is actually in the list, but the signature is different

        let alert = NSAlert()
        alert.messageText = .init(
            localized: .init(
                "Accessibility Request: Title",
                defaultValue: "\(Bundle.main.appName) Needs Accessibility Permissions"
            )
        )
        alert.informativeText = .init(
            localized: .init(
                "Accessibility Request: Content",
                defaultValue: "Please grant access to be able to resize windows."
            )
        )
        alert.runModal()

        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let status = AXIsProcessTrustedWithOptions(options)

        return status
    }

    /// Determines if the app has accessibility permissions.
    /// - Returns: whether the app has accessibility permissions.
    private static func getStatus() -> Bool {
        AXIsProcessTrusted()
    }

    /// Executes `/usr/bin/tccutil reset Accessibility <Bundle ID>`.
    /// This fully removes any accessibility permissions the user may have previously granted to Loop.
    private static func resetAccessibility() {
        _ = try? Process.run(URL(filePath: "/usr/bin/tccutil"), arguments: ["reset", "Accessibility", Bundle.main.bundleID])
    }
}

private extension Notification.Name {
    /// Not publicly documented, but gets sent when ANY application's AX API permission change.
    /// From `HIServices.framework`
    static let AXPermissionsChanged = Notification.Name(rawValue: "com.apple.accessibility.api")
}
