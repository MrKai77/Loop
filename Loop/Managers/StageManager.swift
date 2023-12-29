//
//  StageManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-12-24.
//

import SwiftUI

class StageManager {
    private static let windowManagerDefaults = UserDefaults(suiteName: "com.apple.WindowManager")
    private static let dockDefaults = UserDefaults(suiteName: "com.apple.dock")

    static var available: Bool {
        guard #available(macOS 13, *) else {
            return false
        }
        return true
    }

    static var enabled: Bool {
        guard let value = windowManagerDefaults?.object(forKey: "GloballyEnabled") as? Bool else {
            return false
        }
        return value
    }

    static var shown: Bool {
        guard let value = windowManagerDefaults?.object(forKey: "AutoHide") as? Bool else {
            return false
        }
        return !value
    }

    static var position: Edge {
        guard let value = dockDefaults?.object(forKey: "orientation") as? String else {
            return .leading
        }
        return value == "left" ? .trailing : .leading
    }
}
