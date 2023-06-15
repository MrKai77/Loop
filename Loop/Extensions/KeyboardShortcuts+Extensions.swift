//
//  KeyboardShortcuts+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import Foundation
import KeyboardShortcuts

// Add variables for keyboard shortcuts
extension KeyboardShortcuts.Name {
    static let maximize = Self("resizeMaximize", default: .init(.slash, modifiers: [.control, .option]))
    
    static let topHalf = Self("topHalf", default: .init(.upArrow, modifiers: [.control, .option]))
    static let rightHalf = Self("rightHalf", default: .init(.rightArrow, modifiers: [.control, .option]))
    static let bottomHalf = Self("bottomHalf", default: .init(.downArrow, modifiers: [.control, .option]))
    static let leftHalf = Self("leftHalf", default: .init(.leftArrow, modifiers: [.control, .option]))
    
    static let topRightQuarter = Self("topRightQuarter", default: .init(.i, modifiers: [.control, .option]))
    static let topLeftQuarter = Self("topLeftQuarter", default: .init(.u, modifiers: [.control, .option]))
    static let bottomRightQuarter = Self("bottomRightQuarter", default: .init(.k, modifiers: [.control, .option]))
    static let bottomLeftQuarter = Self("bottomLeftQuarter", default: .init(.j, modifiers: [.control, .option]))
    
    static let rightThird = Self("rightThird", default: .init(.d, modifiers: [.control, .option]))
    static let rightTwoThirds = Self("rightTwoThirds", default: .init(.e, modifiers: [.control, .option]))
    static let horizontalCenterThird = Self("HorizontalCenterThird", default: .init(.s, modifiers: [.control, .option]))
    static let leftThird = Self("leftThird", default: .init(.a, modifiers: [.control, .option]))
    static let leftTwoThirds = Self("leftTwoThirds", default: .init(.q, modifiers: [.control, .option]))
}
