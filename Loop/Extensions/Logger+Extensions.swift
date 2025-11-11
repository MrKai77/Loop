//
//  Logger+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-10.
//

import OSLog

extension Logger {
    init(category: String) {
        self.init(subsystem: Bundle.main.bundleID, category: category)
    }
}
