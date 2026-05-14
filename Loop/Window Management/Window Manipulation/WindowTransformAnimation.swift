//
//  WindowTransformAnimation.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-02.
//

import SwiftUI

/// Animate a window's resize!
@MainActor
final class WindowTransformAnimation: NSAnimation {
    private var targetFrame: CGRect
    private let originalFrame: CGRect
    private let window: Window
    private let bounds: CGRect
    private let shouldSetSize: Bool
    private let targetEdges: Edge.Set
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
        self.targetEdges = newRect.getEdgesTouchingBounds(bounds)
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

        let requestedFrame = CGRect(
            x: round(originalFrame.origin.x + value * (targetFrame.origin.x - originalFrame.origin.x)),
            y: round(originalFrame.origin.y + value * (targetFrame.origin.y - originalFrame.origin.y)),
            width: round(originalFrame.size.width + value * (targetFrame.size.width - originalFrame.size.width)),
            height: round(originalFrame.size.height + value * (targetFrame.size.height - originalFrame.size.height))
        )

        var newFrame = requestedFrame

        if shouldSetSize, lastWindowFrame.size != requestedFrame.size {
            window.setSize(requestedFrame.size)
            if bounds != .zero {
                let actualFrame = window.frame
                newFrame = WindowEngine.anchoredFrame(
                    for: actualFrame.size,
                    within: requestedFrame,
                    targetEdges: targetEdges,
                    bounds: bounds
                )
            }
        } else if bounds != .zero {
            newFrame = newFrame.pushInside(bounds)
        }

        if lastWindowFrame.origin != newFrame.origin {
            window.setPosition(newFrame.origin)
        }

        lastWindowFrame = window.frame
    }
}
