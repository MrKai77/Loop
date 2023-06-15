//
//  Notification+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import Foundation

// Add a notification name to specify then the user changes their resizing direction in the radial menu
extension Notification.Name {
    static let currentResizingDirectionChanged = Notification.Name("currentResizingDirectionChanged")
}
