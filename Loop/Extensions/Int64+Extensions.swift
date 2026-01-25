//
//  Int64+Extensions.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import Foundation

extension Int64 {
    var formattedBytes: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = false // Always use MB, no GB/KB
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: self)
    }
}
