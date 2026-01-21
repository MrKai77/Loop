//
//  PaddingConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-02-01.
//

import Defaults
import SwiftUI

struct PaddingConfiguration: Codable, Defaults.Serializable, Hashable {
    var window: CGFloat
    var externalBar: CGFloat
    var top: CGFloat
    var bottom: CGFloat
    var right: CGFloat
    var left: CGFloat

    var configureScreenPadding: Bool

    var totalTopPadding: CGFloat {
        top + externalBar
    }

    static var zero = PaddingConfiguration(
        window: 0,
        externalBar: 0,
        top: 0,
        bottom: 0,
        right: 0,
        left: 0,
        configureScreenPadding: false
    )

    var allEqual: Bool {
        window == top && window == bottom && window == right && window == left
    }

    func applyTo(bounds: CGRect) -> CGRect {
        bounds
            .padding(.leading, left)
            .padding(.trailing, right)
            .padding(.bottom, bottom)
            .padding(.top, totalTopPadding)
    }

    /// Applies padding to a frame that was calculated using non-padded bounds.
    /// This scales the frame proportionally into the padded working area and applies inner window padding.
    /// - Parameters:
    ///   - frame: The frame calculated using non-padded bounds.
    ///   - bounds: The original non-padded bounds (e.g., screen frame).
    ///   - action: The window action, used to determine padding behavior.
    ///   - window: The window being resized, if any.
    /// - Returns: The frame with padding applied.
    func apply(to frame: CGRect, bounds: CGRect, action: WindowAction, window: Window?) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else { return frame }

        // Calculate padded working area
        let paddedBounds = applyTo(bounds: bounds)

        // Scale the frame proportionally from non-padded bounds to padded bounds
        let relativeX = (frame.minX - bounds.minX) / bounds.width
        let relativeY = (frame.minY - bounds.minY) / bounds.height
        let relativeWidth = frame.width / bounds.width
        let relativeHeight = frame.height / bounds.height

        var result = CGRect(
            x: paddedBounds.minX + paddedBounds.width * relativeX,
            y: paddedBounds.minY + paddedBounds.height * relativeY,
            width: paddedBounds.width * relativeWidth,
            height: paddedBounds.height * relativeHeight
        )

        // Convert to integer rects for AX API (only for non-manipulating actions)
        if !action.willManipulateExistingWindowFrame {
            let integerPaddedBounds = paddedBounds.integerRect()
            result = result.integerRect()

            // Handle non-resizable windows by centering within the frame
            if let window, window.isResizable == false {
                return window.frame.size
                    .center(inside: result)
                    .pushInside(integerPaddedBounds)
            }
        }

        // Apply inner padding if applicable
        guard action.isPaddingApplicable else { return result }

        result = applyInnerPadding(to: result, paddedBounds: paddedBounds, action: action)

        return result
    }

    /// Applies inner window padding to the sides of the frame that don't touch the bounds edges.
    private func applyInnerPadding(to frame: CGRect, paddedBounds: CGRect, action: WindowAction) -> CGRect {
        guard !action.direction.willMove else { return frame }

        var result = frame.intersection(paddedBounds)
        let halfPadding = window / 2

        // Handle macOS center special case
        if action.direction == .macOSCenter, frame.height >= paddedBounds.height {
            result.origin.y = paddedBounds.minY
            result.size.height = paddedBounds.height
        }

        // Center actions don't get inner padding
        if action.direction == .center || action.direction == .macOSCenter {
            return result
        }

        // Apply half padding to sides not touching bounds
        if abs(result.minX - paddedBounds.minX) > 1 {
            result = result.padding(.leading, halfPadding)
        }
        if abs(result.maxX - paddedBounds.maxX) > 1 {
            result = result.padding(.trailing, halfPadding)
        }
        if abs(result.minY - paddedBounds.minY) > 1 {
            result = result.padding(.top, halfPadding)
        }
        if abs(result.maxY - paddedBounds.maxY) > 1 {
            result = result.padding(.bottom, halfPadding)
        }

        return result
    }
}

extension PaddingConfiguration {
    static func getConfiguredPadding(for screen: NSScreen?) -> PaddingConfiguration {
        if #available(macOS 15, *), Defaults[.useSystemWindowManagerWhenAvailable] {
            guard SystemWindowManager.MoveAndResize.enablePadding else {
                return .zero
            }

            let padding = SystemWindowManager.MoveAndResize.padding

            return PaddingConfiguration(
                window: padding,
                externalBar: 0,
                top: padding,
                bottom: padding,
                right: padding,
                left: padding,
                configureScreenPadding: false
            )
        } else {
            let respectsPaddingThreshold = if let screen {
                Defaults[.paddingMinimumScreenSize] == 0 || screen.diagonalSize > Defaults[.paddingMinimumScreenSize]
            } else {
                true
            }
            let enablePadding = Defaults[.enablePadding] && respectsPaddingThreshold

            return enablePadding ? Defaults[.padding] : .zero
        }
    }
}
