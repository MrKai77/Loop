//
//  SnappingManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-04.
//

import Cocoa

class SnappingManager {

    private var draggingWindow: Window?
    private var initialWindowPosition: CGPoint?
    private var direction: WindowDirection = .noAction

    private let previewController = PreviewController()

    init() {
        self.addObservers()
    }

    func addObservers() {
        let leftMouseDraggedMonitor = EventMonitor(eventMask: .leftMouseDragged) { cgEvent in
            // Process window (only ONCE during a window drag)
            if self.draggingWindow == nil {
                guard let mousePosition = NSEvent.mouseLocation.flipY,
                      let draggingWindow = WindowEngine.windowAtPosition(mousePosition) else { return Unmanaged.passRetained(cgEvent) }
                self.draggingWindow = draggingWindow
                self.initialWindowPosition = draggingWindow.position
            }

            if let window = self.draggingWindow,
               let mousePosition = NSEvent.mouseLocation.flipY,
               let screen = NSScreen.screenWithMouse,
               let screenFrame = screen.visibleFrame.flipY,
               self.initialWindowPosition != window.position {
                let ignoredFrame = screenFrame.insetBy(dx: 20, dy: 20)  // 10px of snap area on each side

                if !ignoredFrame.contains(mousePosition) {
                    self.direction = WindowDirection.snapDirection(
                        mouseLocation: mousePosition,
                        currentDirection: self.direction,
                        screenFrame: screenFrame,
                        ignoredFrame: ignoredFrame
                    )

                    self.previewController.show(screen: screen)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name.directionChanged,
                            object: nil,
                            userInfo: ["direction": self.direction]
                        )
                    }
                } else {
                    self.direction = .noAction
                    self.previewController.close()
                }
            }

            return Unmanaged.passRetained(cgEvent)
        }

        let leftMouseUpMonitor = EventMonitor(eventMask: .leftMouseUp) { cgEvent in
            if let window = self.draggingWindow,
               let screen = NSScreen.screenWithMouse,
               self.initialWindowPosition != window.position {
                WindowEngine.resize(window: window, direction: self.direction, screen: screen)
            }
            self.previewController.close()
            self.draggingWindow = nil
            return Unmanaged.passRetained(cgEvent)
        }

        leftMouseDraggedMonitor.start()
        leftMouseUpMonitor.start()
    }
}
