//
//  UNNotification+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2024-01-15.
//

import SwiftUI
import UserNotifications

// Thanks https://stackoverflow.com/questions/45226847/unnotificationattachment-failing-to-attach-image
extension UNNotificationAttachment {
    static func create(_ imgData: NSData) -> UNNotificationAttachment? {
        let imageFileIdentifier = UUID().uuidString + ".jpeg"

        let fileManager = FileManager.default
        let tmpSubFolderName = ProcessInfo.processInfo.globallyUniqueString
        let tmpSubFolderURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
            tmpSubFolderName,
            isDirectory: true
        )

        do {
            try fileManager.createDirectory(at: tmpSubFolderURL!, withIntermediateDirectories: true, attributes: nil)
            let fileURL = tmpSubFolderURL?.appendingPathComponent(imageFileIdentifier)
            try imgData.write(to: fileURL!, options: [])
            let imageAttachment = try UNNotificationAttachment(
                identifier: imageFileIdentifier,
                url: fileURL!,
                options: nil
            )
            return imageAttachment
        } catch {
            NSLog("Failed to create attachment: \(error.localizedDescription)")
        }

        return nil
    }
}
