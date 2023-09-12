//
//  SnappingManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-04.
//

import Cocoa

class SnappingManager {

    static let shared = SnappingManager()

    private var draggingWindow: Window?
    private var initialWindowPosition: CGPoint?
    private var direction: WindowDirection = .noAction

    private let previewController = PreviewController()

    private var leftMouseDraggedMonitor: EventMonitor?
    private var leftMouseUpMonitor: EventMonitor?

    func addObservers() {
        self.leftMouseDraggedMonitor = EventMonitor(eventMask: .leftMouseDragged) { cgEvent in
            // Process window (only ONCE during a window drag)
            if self.draggingWindow == nil {
                self.setCurrentDraggingWindow()
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

        self.leftMouseUpMonitor = EventMonitor(eventMask: .leftMouseUp) { cgEvent in
            if let window = self.draggingWindow,
               let screen = NSScreen.screenWithMouse,
               self.initialWindowPosition != window.position {
                DispatchQueue.main.async {
                    WindowEngine.resize(window, to: self.direction, screen)
                }
            }
            self.previewController.close()
            self.draggingWindow = nil
            return Unmanaged.passRetained(cgEvent)
        }

        leftMouseDraggedMonitor!.start()
        leftMouseUpMonitor!.start()
    }

    func removeObservers() {
        leftMouseDraggedMonitor!.stop()
        leftMouseUpMonitor!.stop()
    }

    private func setCurrentDraggingWindow() {
        guard let mousePosition = NSEvent.mouseLocation.flipY,
              let draggingWindow = WindowEngine.windowAtPosition(mousePosition) else {
            return
        }
        self.draggingWindow = draggingWindow
        self.initialWindowPosition = draggingWindow.position
    }
}
