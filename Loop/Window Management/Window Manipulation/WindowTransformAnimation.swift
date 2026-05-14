//
//  WindowTransformAnimation.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-02.
//

import SwiftUI

private enum ResizeAnimationConstraint {
    case none
    case fixedAxes(width: Bool, height: Bool)
    case fixedAspectRatio(CGFloat)
    
    var hasFixedAxes: Bool {
        if case .fixedAxes = self {
            return true
        }
        
        return false
    }
}

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
    private var constraint: ResizeAnimationConstraint = .none

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
        var currentOrigin = lastWindowFrame.origin
        let resizeTolerance: CGFloat = 2

        let sizeToSet = sizeToSet(for: requestedFrame)

        if shouldSetSize, !lastWindowFrame.size.approximatelyEqual(to: sizeToSet, tolerance: resizeTolerance) {
            let growsHorizontally = sizeToSet.width > lastWindowFrame.width + resizeTolerance
            let growsVertically = sizeToSet.height > lastWindowFrame.height + resizeTolerance

            if let preResizeOrigin = predictedPreResizeOrigin(
                requestedFrame: requestedFrame,
                sizeToSet: sizeToSet
            ) {
                if !lastWindowFrame.origin.approximatelyEqual(to: preResizeOrigin, tolerance: 1) {
                    window.setPosition(preResizeOrigin)
                    currentOrigin = preResizeOrigin
                }
            } else if growsHorizontally || growsVertically {
                var preResizeOrigin = lastWindowFrame.origin
                if growsHorizontally {
                    preResizeOrigin.x = requestedFrame.origin.x
                }
                if growsVertically {
                    preResizeOrigin.y = requestedFrame.origin.y
                }
                if !lastWindowFrame.origin.approximatelyEqual(to: preResizeOrigin, tolerance: 1) {
                    window.setPosition(preResizeOrigin)
                    currentOrigin = preResizeOrigin
                }
            }

            window.setSize(sizeToSet)
            if bounds != .zero {
                let actualFrame = window.frame
                updateConstraint(actualFrame: actualFrame, requestedFrame: requestedFrame, tolerance: resizeTolerance)

                if WindowEngine.shouldAnchorDuringAnimation(
                    actualSize: actualFrame.size,
                    requestedSize: requestedFrame.size
                ) {
                    newFrame = WindowEngine.anchoredFrame(
                        for: actualFrame.size,
                        within: requestedFrame,
                        targetEdges: targetEdges,
                        bounds: bounds
                    )
                } else {
                    newFrame = CGRect(
                        origin: requestedFrame.origin,
                        size: actualFrame.size
                    )
                    .pushInside(bounds)
                }
            }
        } else if bounds != .zero, constraint.hasFixedAxes {
            newFrame = WindowEngine.anchoredFrame(
                for: lastWindowFrame.size,
                within: requestedFrame,
                targetEdges: targetEdges,
                bounds: bounds
            )
        } else if bounds != .zero {
            newFrame = newFrame.pushInside(bounds)
        }

        if !currentOrigin.approximatelyEqual(to: newFrame.origin, tolerance: 1) {
            window.setPosition(newFrame.origin)
        }

        lastWindowFrame = window.frame
    }

    private func sizeToSet(for requestedFrame: CGRect) -> CGSize {
        switch constraint {
        case .none, .fixedAspectRatio:
            return requestedFrame.size
        case let .fixedAxes(width, height):
            return CGSize(
                width: width ? lastWindowFrame.width : requestedFrame.width,
                height: height ? lastWindowFrame.height : requestedFrame.height
            )
        }
    }

    private func predictedPreResizeOrigin(requestedFrame: CGRect, sizeToSet: CGSize) -> CGPoint? {
        guard case let .fixedAspectRatio(aspectRatio) = constraint,
              bounds != .zero else {
            return nil
        }

        let predictedSize = sizeToSet.fitting(aspectRatio: aspectRatio)
        return WindowEngine.anchoredFrame(
            for: predictedSize,
            within: requestedFrame,
            targetEdges: targetEdges,
            bounds: bounds
        )
        .origin
    }

    private func updateConstraint(actualFrame: CGRect, requestedFrame: CGRect, tolerance: CGFloat) {
        if case .fixedAxes = constraint {
            return
        }

        let acceptedSize = actualFrame.size
        guard acceptedSize.width <= requestedFrame.width + tolerance,
              acceptedSize.height <= requestedFrame.height + tolerance else {
            constraint = .none
            return
        }

        let shouldLockWidth = shouldLockSizeAxis(
            actual: actualFrame.width,
            previous: lastWindowFrame.width,
            requested: requestedFrame.width,
            tolerance: tolerance
        )

        let shouldLockHeight = shouldLockSizeAxis(
            actual: actualFrame.height,
            previous: lastWindowFrame.height,
            requested: requestedFrame.height,
            tolerance: tolerance
        )

        if shouldLockWidth || shouldLockHeight {
            constraint = .fixedAxes(width: shouldLockWidth, height: shouldLockHeight)
        } else if WindowEngine.shouldAnchorDuringAnimation(
            actualSize: acceptedSize,
            requestedSize: requestedFrame.size,
            tolerance: tolerance
        ), acceptedSize.width > 0, acceptedSize.height > 0 {
            constraint = .fixedAspectRatio(acceptedSize.width / acceptedSize.height)
        }
    }

    private func shouldLockSizeAxis(
        actual: CGFloat,
        previous: CGFloat,
        requested: CGFloat,
        tolerance: CGFloat
    ) -> Bool {
        let requestedChanged = !requested.approximatelyEquals(to: previous, tolerance: tolerance)
        let actualDidNotChange = actual.approximatelyEquals(to: previous, tolerance: tolerance)
        let constrainedBelowRequest = actual <= requested + tolerance

        return requestedChanged && actualDidNotChange && constrainedBelowRequest
    }
}

private extension CGSize {
    func fitting(aspectRatio: CGFloat) -> CGSize {
        guard width > 0, height > 0, aspectRatio > 0 else {
            return self
        }

        let sizeAspectRatio = width / height
        if sizeAspectRatio > aspectRatio {
            return CGSize(width: height * aspectRatio, height: height)
        } else {
            return CGSize(width: width, height: width / aspectRatio)
        }
    }
}
