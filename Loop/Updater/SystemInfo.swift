//
//  SystemInfo.swift
//  Loop
//
//  Created by Kami on 2026-01-22.
//

import Foundation

public enum SystemInfo {
    public static var deviceModel: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    public static var osVersion: String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }

    public static var osVersionString: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    public static var isRunningOnMac: Bool {
        #if os(macOS)
            return true
        #else
            return false
        #endif
    }

    public static var architecture: String {
        #if arch(x86_64)
            return "x86_64"
        #elseif arch(arm64)
            return "arm64"
        #else
            return "unknown"
        #endif
    }

    public static var hostname: String {
        ProcessInfo.processInfo.hostName
    }
}
