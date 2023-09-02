//
//  WindowTransformAnimation.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-02.
//

import SwiftUI

/// Animate a window's resize!
class WindowTransformAnimation: NSAnimation {
    private var targetFrame: CGRect
    private let oldFrame: CGRect
    private let window: Window

    init(_ newRect: CGRect, window: Window) {
        self.targetFrame = newRect
        self.oldFrame = window.frame
        self.window = window
        super.init(duration: 0.2, animationCurve: .easeOut)
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
            let value = CGFloat(self.currentValue)
            let newFrame = CGRect(
                x: oldFrame.origin.x + value * (targetFrame.origin.x - oldFrame.origin.x),
                y: oldFrame.origin.y + value * (targetFrame.origin.y - oldFrame.origin.y),
                width: oldFrame.size.width + value * (targetFrame.size.width - oldFrame.size.width),
                height: oldFrame.size.height + value * (targetFrame.size.height - oldFrame.size.height)
            )

            window.setFrame(newFrame)
        }
    }
}
