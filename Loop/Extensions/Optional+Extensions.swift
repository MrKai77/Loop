//
//  Optional+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-12-26.
//

import Foundation

extension Optional where Wrapped == String {
    public var bound: String {
        get {
            return self ?? ""
        }
        set {
            self = newValue.isEmpty ? nil : newValue
        }
    }
}
