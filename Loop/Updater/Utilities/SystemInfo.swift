//
//  SystemInfo.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import Foundation

enum SystemInfo {
    static var deviceModel: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    enum Architecture: String, CaseIterable {
        case x86_64
        case arm64
        case other
    }

    static var architecture: Architecture {
        #if arch(x86_64)
            return .x86_64
        #elseif arch(arm64)
            return .arm64
        #else
            return .other
        #endif
    }
}
