import Foundation

@objc protocol PrivilegedInstallerProtocol {
    func atomicSwap(
        _ currentURL: URL,
        stagedURL: URL,
        backupURL: URL,
        withReply reply: @escaping (NSError?) -> ()
    )

    func restoreFromBackup(
        _ currentURL: URL,
        backupURL: URL,
        withReply reply: @escaping (NSError?) -> ()
    )

    func removeItem(
        _ itemURL: URL,
        withReply reply: @escaping (NSError?) -> ()
    )
}

enum PrivilegedInstallerConstants {
    static let helperExecutableName = "LoopUpdaterHelper"
    static let serviceName = "com.MrKai77.Loop.UpdaterJob"
    static let appBundleIdentifier = "com.MrKai77.Loop"
    static let authorizedClientRequirement = "identifier \"com.MrKai77.Loop\" and anchor apple generic and certificate leaf[subject.OU] = \"5F967GYF84\""
}
