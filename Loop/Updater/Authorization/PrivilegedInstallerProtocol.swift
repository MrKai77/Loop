import Foundation

// NOTE: Keep this protocol in sync with LoopUpdaterHelper/PrivilegedInstallerProtocol.swift.
@objc protocol PrivilegedInstallerProtocol {
    func atomicSwap(
        _ currentPath: String,
        stagedPath: String,
        backupPath: String,
        withReply reply: @escaping (NSError?) -> Void
    )

    func restoreFromBackup(
        _ currentPath: String,
        backupPath: String,
        withReply reply: @escaping (NSError?) -> Void
    )

    func removeItem(
        _ path: String,
        withReply reply: @escaping (NSError?) -> Void
    )
}

enum PrivilegedInstallerConstants {
    static let helperExecutableName = "LoopUpdaterHelper"
    static let serviceName = "com.MrKai77.Loop.UpdaterJob"
}
