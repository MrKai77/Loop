import Foundation

@objc protocol PrivilegedInstallerProtocol {
    func prepareBackup(_ backupDirectory: String, withReply reply: @escaping (NSError?) -> Void)
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
    func removeItem(_ path: String, withReply reply: @escaping (NSError?) -> Void)
}

enum PrivilegedInstallerConstants {
    static let helperLabel = "com.MrKai77.Loop.UpdaterHelper"
    static let appBundleIdentifier = "com.MrKai77.Loop"
}
