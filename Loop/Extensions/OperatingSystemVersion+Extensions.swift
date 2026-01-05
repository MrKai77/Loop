//
//  OperatingSystemVersion+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-05.
//

import Foundation

extension OperatingSystemVersion: @retroactive CustomStringConvertible {
    public var description: String {
        "\(majorVersion).\(minorVersion).\(patchVersion)"
    }
}
