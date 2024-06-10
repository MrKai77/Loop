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

    static var enabled: Bool {
        windowManagerDefaults?.bool(forKey: "GloballyEnabled") ?? false
    }

    static var shown: Bool {
        !(windowManagerDefaults?.bool(forKey: "AutoHide") ?? true)
    }

    static var position: Edge {
        dockDefaults?.string(forKey: "orientation") == "left" ? .trailing : .leading
    }
}
