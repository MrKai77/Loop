//
//  WindowTransformAnimation.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-02.
//

import SwiftUI

// Animate a window's resize!
class WindowTransformAnimation: NSAnimation {
    private var targetFrame: CGRect
    private let originalFrame: CGRect
    private let window: Window
    private let bounds: CGRect
    private let completionHandler: () -> Void

    private var lastWindowFrame: CGRect = .zero

    // Using ids for each ongoing animation, we can cancel as a new window animation is started for that specific window
    private var id: UUID = UUID()
    static var currentAnimations: [CGWindowID: UUID] = [:]

    init(_ newRect: CGRect, window: Window, bounds: CGRect, completionHandler: @escaping () -> Void) {
        self.targetFrame = newRect
        self.originalFrame = window.frame
        self.window = window
        self.bounds = bounds
        self.completionHandler = completionHandler
        super.init(duration: 0.3, animationCurve: .easeOut)
        self.frameRate = 60.0
        self.animationBlockingMode = .nonblocking
        self.lastWindowFrame = originalFrame

        WindowTransformAnimation.currentAnimations[window.cgWindowID] = self.id
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startInBackground() {
        DispatchQueue.global().async { [self] in
            self.start()
            RunLoop.current.run()
        }
    }

    override public var currentProgress: NSAnimation.Progress {
        didSet {
            guard WindowTransformAnimation.currentAnimations.contains(where: { $0.value == self.id }) else {
                stop()
                return
            }

            let value = CGFloat(1.0 - pow(1.0 - self.currentValue, 3))

            var newFrame = CGRect(
                x: originalFrame.origin.x + value * (targetFrame.origin.x - originalFrame.origin.x),
                y: originalFrame.origin.y + value * (targetFrame.origin.y - originalFrame.origin.y),
                width: originalFrame.size.width + value * (targetFrame.size.width - originalFrame.size.width),
                height: originalFrame.size.height + value * (targetFrame.size.height - originalFrame.size.height)
            )

            // Keep the window inside the bounds
            if newFrame.maxX + (lastWindowFrame.width - newFrame.width) > bounds.maxX {
                newFrame.origin.x = bounds.maxX - lastWindowFrame.width
            }
            if newFrame.maxY + (lastWindowFrame.height - newFrame.height) > bounds.maxY {
                newFrame.origin.y = bounds.maxY - lastWindowFrame.height
            }

            window.setPosition(newFrame.origin)
            window.setSize(newFrame.size)
            lastWindowFrame = window.frame

            if currentProgress >= 1.0 {
                WindowTransformAnimation.currentAnimations[window.cgWindowID] = nil
                completionHandler()
            }
        }
    }
}
