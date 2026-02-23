import Foundation

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
    static let appBundleIdentifier = "com.MrKai77.Loop"
    static let authorizedClientRequirement = "identifier \"com.MrKai77.Loop\" and anchor apple generic and certificate leaf[subject.OU] = \"5F967GYF84\""
}
