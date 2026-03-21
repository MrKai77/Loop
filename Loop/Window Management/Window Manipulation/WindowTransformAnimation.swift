//
//  WindowTransformAnimation.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-02.
//

import SwiftUI

/// Animate a window's resize!
final class WindowTransformAnimation: NSAnimation {
    private var targetFrame: CGRect
    private let originalFrame: CGRect
    private let window: Window
    private let bounds: CGRect
    private let shouldSetSize: Bool
    private var didCallCompletionHandler: Bool = false
    private let completionHandler: (Error?) -> ()

    private var lastWindowFrame: CGRect = .zero

    // Using ids for each ongoing animation, we can cancel as a new window animation is started for that specific window
    private var id: UUID = .init()
    static var activeAnimationByWindow: [CGWindowID: WindowTransformAnimation] = [:]

    init(
        _ newRect: CGRect,
        window: Window,
        bounds: CGRect,
        shouldSetSize: Bool,
        completionHandler: @escaping (Error?) -> ()
    ) {
        self.targetFrame = newRect
        self.originalFrame = window.frame
        self.window = window
        self.bounds = bounds
        self.shouldSetSize = shouldSetSize
        self.completionHandler = completionHandler
        super.init(duration: 0.3, animationCurve: .easeOut)
        self.frameRate = Float(NSScreen.main?.displayMode?.refreshRate ?? 60.0)
        self.animationBlockingMode = .nonblocking
        self.lastWindowFrame = originalFrame

        if let existing = Self.activeAnimationByWindow[window.cgWindowID] {
            existing.cancel()
        }

        Self.activeAnimationByWindow[window.cgWindowID] = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor
    override func start() {
        super.start()
    }

    override func stop() {
        super.stop()
        Self.activeAnimationByWindow[window.cgWindowID] = nil

        if !didCallCompletionHandler {
            completionHandler(nil)
        }

        didCallCompletionHandler = true
    }

    func cancel() {
        super.stop()
        Self.activeAnimationByWindow[window.cgWindowID] = nil

        if !didCallCompletionHandler {
            completionHandler(CancellationError())
        }

        didCallCompletionHandler = true
    }

    override var currentProgress: NSAnimation.Progress {
        didSet {
            apply(progress: currentValue)

            if currentValue >= 1.0 {
                stop()
            }
        }
    }

    private func apply(progress: Float) {
        let value = CGFloat(1.0 - pow(1.0 - progress, 3))

        var newFrame = CGRect(
            x: round(originalFrame.origin.x + value * (targetFrame.origin.x - originalFrame.origin.x)),
            y: round(originalFrame.origin.y + value * (targetFrame.origin.y - originalFrame.origin.y)),
            width: round(originalFrame.size.width + value * (targetFrame.size.width - originalFrame.size.width)),
            height: round(originalFrame.size.height + value * (targetFrame.size.height - originalFrame.size.height))
        )

        // Keep the window inside the bounds
        if bounds != .zero {
            let xDiff = lastWindowFrame.width - newFrame.width
            if newFrame.maxX + xDiff > lastWindowFrame.maxX || currentValue >= 0.5,
               newFrame.maxX + xDiff > bounds.maxX {
                newFrame.origin.x = bounds.maxX - lastWindowFrame.width
            }

            let yDiff = lastWindowFrame.height - newFrame.height
            if newFrame.maxY + yDiff > lastWindowFrame.maxY || currentValue >= 0.5,
               newFrame.maxY + yDiff > bounds.maxY {
                newFrame.origin.y = bounds.maxY - lastWindowFrame.height
            }
        }

        if lastWindowFrame.origin != newFrame.origin {
            window.setPosition(newFrame.origin)
        }

        if shouldSetSize, lastWindowFrame.size != newFrame.size {
            window.setSize(newFrame.size)
        }

        lastWindowFrame = window.frame
    }
}
