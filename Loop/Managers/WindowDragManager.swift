//
//  WindowDragManager.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-04.
//

import Cocoa
import Defaults

class WindowDragManager {

    private var draggingWindow: Window?
    private var initialWindowPosition: CGPoint?
    private var direction: WindowDirection = .noAction

    private let previewController = PreviewController()

    private var leftMouseDraggedMonitor: CGEventMonitor?
    private var leftMouseUpMonitor: CGEventMonitor?

    func addObservers() {
        self.leftMouseDraggedMonitor = CGEventMonitor(eventMask: .leftMouseDragged) { cgEvent in
            // Process window (only ONCE during a window drag)
            if self.draggingWindow == nil {
                self.setCurrentDraggingWindow()
            }

            if let window = self.draggingWindow,
               self.initialWindowPosition != window.position {
                // If window is not at initial position...

                if Defaults[.restoreWindowFrameOnDrag] {
                    self.restoreInitialWindowSize(window)
                }

                if Defaults[.windowSnapping] {
                    self.getWindowSnapDirection()
                }
            }

            return Unmanaged.passRetained(cgEvent)
        }

        self.leftMouseUpMonitor = CGEventMonitor(eventMask: .leftMouseUp) { cgEvent in

            if let window = self.draggingWindow,
               self.initialWindowPosition != window.position {
                // If window is not at initial position...

                if Defaults[.windowSnapping] {
                    self.attemptWindowSnap(window)
                }
            }

            self.previewController.close()
            self.draggingWindow = nil

            return Unmanaged.passRetained(cgEvent)
        }

        leftMouseDraggedMonitor!.start()
        leftMouseUpMonitor!.start()
    }

    private func setCurrentDraggingWindow() {
        guard let mousePosition = NSEvent.mouseLocation.flipY,
              let draggingWindow = WindowEngine.windowAtPosition(mousePosition) else {
            return
        }
        self.draggingWindow = draggingWindow
        self.initialWindowPosition = draggingWindow.position
    }

    private func restoreInitialWindowSize(_ window: Window) {
        guard let initialFrame = WindowRecords.getInitialFrame(for: window) else { return }
        window.setSize(initialFrame.size)
        WindowRecords.eraseRecords(for: window)
    }

    private func getWindowSnapDirection() {
        guard
            let mousePosition = NSEvent.mouseLocation.flipY,
            let screen = NSScreen.screenWithMouse,
            let screenFrame = screen.visibleFrame.flipY
        else {
            return
        }

         let ignoredFrame = screenFrame.insetBy(dx: 20, dy: 20)  // 10px of snap area on each side

         if !ignoredFrame.contains(mousePosition) {
             self.direction = WindowDirection.processSnap(
                 mouseLocation: mousePosition,
                 currentDirection: self.direction,
                 screenFrame: screenFrame,
                 ignoredFrame: ignoredFrame
             )

             self.previewController.open(screen: screen, window: nil)
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

    private func attemptWindowSnap(_ window: Window) {
        guard
            let screen = NSScreen.screenWithMouse
        else {
            return
        }

        DispatchQueue.main.async {
            WindowEngine.resize(window, to: self.direction, screen)
        }
    }
}
