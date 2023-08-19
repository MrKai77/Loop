//
//  Notification+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import Foundation

extension Notification.Name {
    static let directionChanged = Notification.Name("directionChanged")
    static let forceCloseLoop = Notification.Name("forceCloseLoop")
    static let finishedLooping = Notification.Name("finishedLooping")
}
