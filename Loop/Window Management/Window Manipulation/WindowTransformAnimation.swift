//
//  WindowTransformAnimation.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-02.
//

import SwiftUI

// Animate a window's resize!
final class WindowTransformAnimation: NSAnimation {
    private var targetFrame: CGRect
    private let originalFrame: CGRect
    private let window: Window
    private let bounds: CGRect
    private let completionHandler: () -> ()

    private var lastWindowFrame: CGRect = .zero

    // Using ids for each ongoing animation, we can cancel as a new window animation is started for that specific window
    private var id: UUID = .init()
    static var currentAnimations: [CGWindowID: UUID] = [:]

    init(_ newRect: CGRect, window: Window, bounds: CGRect, completionHandler: @escaping () -> ()) {
        self.targetFrame = newRect
        self.originalFrame = window.frame
        self.window = window
        self.bounds = bounds
        self.completionHandler = completionHandler
        super.init(duration: 0.3, animationCurve: .easeOut)
        self.frameRate = Float(NSScreen.main?.displayMode?.refreshRate ?? 60.0)
        self.animationBlockingMode = .nonblocking
        self.lastWindowFrame = originalFrame

        WindowTransformAnimation.currentAnimations[window.cgWindowID] = id
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startInBackground() {
        DispatchQueue.global().async { [self] in
            start()
            RunLoop.current.run()
        }
    }

    override var currentProgress: NSAnimation.Progress {
        didSet {
            guard WindowTransformAnimation.currentAnimations.contains(where: { $0.value == self.id }) else {
                stop()
                return
            }

            let value = CGFloat(1.0 - pow(1.0 - currentValue, 3))

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
                window.position = newFrame.origin
            }

            if lastWindowFrame.size != newFrame.size {
                window.size = newFrame.size
            }

            lastWindowFrame = newFrame

            if currentProgress >= 1.0 {
                WindowTransformAnimation.currentAnimations[window.cgWindowID] = nil
                completionHandler()
            }
        }
    }
}
