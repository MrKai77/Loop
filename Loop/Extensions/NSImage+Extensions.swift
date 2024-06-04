//
//  NSImage+Extensions.swift
//  Loop
//
//  Created by Dirk Mika on 15.03.24.
//

import AppKit
import Foundation

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        NSImage(size: newSize, flipped: false) { rect in
            self.draw(
                in: rect,
                from: NSRect(origin: CGPoint.zero, size: self.size),
                operation: NSCompositingOperation.copy,
                fraction: 1.0
            )
            return true
        }
    }
}
