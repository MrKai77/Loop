//
//  Optional+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-12-26.
//

import Foundation

public extension String? {
    var bound: String {
        get {
            self ?? ""
        }
        set {
            self = newValue.isEmpty ? nil : newValue
        }
    }
}
