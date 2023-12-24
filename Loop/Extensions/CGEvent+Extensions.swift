//
//  CGEvent+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-12-23.
//

import Cocoa

extension CGEvent {
    static var mouseLocation: CGPoint? {
        CGEvent(source: nil)?.location
    }
}
