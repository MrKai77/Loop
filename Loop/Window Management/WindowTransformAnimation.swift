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
    private let oldFrame: CGRect
    private let window: Window
    private let completionHandler: (() -> Void)?

    init(_ newRect: CGRect, window: Window, completionHandler: (() -> Void)? = nil) {
        self.targetFrame = newRect
        self.oldFrame = window.frame
        self.window = window
        self.completionHandler = completionHandler
        super.init(duration: 0.3, animationCurve: .linear)
        self.frameRate = 60.0
        self.animationBlockingMode = .nonblocking
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
            let value = CGFloat(1.0 - pow(1.0 - self.currentValue, 3))
            let newFrame = CGRect(
                x: oldFrame.origin.x + value * (targetFrame.origin.x - oldFrame.origin.x),
                y: oldFrame.origin.y + value * (targetFrame.origin.y - oldFrame.origin.y),
                width: oldFrame.size.width + value * (targetFrame.size.width - oldFrame.size.width),
                height: oldFrame.size.height + value * (targetFrame.size.height - oldFrame.size.height)
            )

            window.setPosition(newFrame.origin)
            window.setSize(newFrame.size)

            if let completionHandler = completionHandler, currentProgress == 1 {
                completionHandler()
            }
        }
    }
}
