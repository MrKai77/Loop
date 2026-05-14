//
//  StashedWindowInfo.swift
//  Loop
//
//  Created by Guillaume Clédat on 28/05/2025.
//

import Foundation
import Scribe
import SwiftUI

@Loggable
struct StashedWindowInfo: Equatable {
    let window: Window
    let screen: NSScreen
    let action: WindowAction
    let restoreFrame: CGRect
    let revealedFrame: CGRect
    let stashedFrame: CGRect

    // MARK: - Frame computation

    static func create(window: Window, screen: NSScreen, action: WindowAction, peekSize: CGFloat) async -> StashedWindowInfo {
        let restoreFrame = await WindowRecords.shared.getInitialFrame(for: window) ?? window.frame
        let revealedFrame = await WindowFrameResolver.getRevealedFrame(for: action, window: window, screen: screen)
        let stashedFrame = await WindowFrameResolver.getStashedFrame(for: action, window: window, screen: screen, peekSize: peekSize)

        return StashedWindowInfo(
            window: window,
            screen: screen,
            action: action,
            restoreFrame: restoreFrame,
            revealedFrame: revealedFrame,
            stashedFrame: stashedFrame
        )
    }

    func updatingStashedFrame(peekSize: CGFloat) async -> StashedWindowInfo {
        let stashedFrame = await WindowFrameResolver.getStashedFrame(for: action, window: window, screen: screen, peekSize: peekSize)

        return StashedWindowInfo(
            window: window,
            screen: screen,
            action: action,
            restoreFrame: restoreFrame,
            revealedFrame: revealedFrame,
            stashedFrame: stashedFrame
        )
    }

    func updatingFrames(screen: NSScreen, peekSize: CGFloat) async -> StashedWindowInfo {
        await Self.create(
            window: window,
            screen: screen,
            action: action,
            peekSize: peekSize
        )
    }
}
