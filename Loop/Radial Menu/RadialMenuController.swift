//
//  RadialMenuController.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-23.
//

import SwiftUI
import Defaults

class RadialMenuController {

    private let accessibilityAccessManager = AccessibilityAccessManager()
    private let radialMenuKeybindMonitor = KeybindMonitor.shared
    private let windowEngine = WindowEngine()
    private let loopPreview = PreviewController()
    private let iconManager = IconManager()

    private var currentResizingDirection: WindowDirection = .noAction
    private var isLoopRadialMenuShown: Bool = false
    private var loopRadialMenuWindowController: NSWindowController?
    private var frontmostWindow: AXUIElement?

    func showRadialMenu(frontmostWindow: AXUIElement?) {
        if let windowController = loopRadialMenuWindowController {
            windowController.window?.orderFrontRegardless()
            return
        }

        currentResizingDirection = .noAction

        let mouseX: CGFloat = NSEvent.mouseLocation.x
        let mouseY: CGFloat = NSEvent.mouseLocation.y

        let windowSize: CGFloat = 250

        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: true,
                            screen: NSApp.keyWindow?.screen)
        panel.collectionBehavior = .canJoinAllSpaces
        panel.hasShadow = false
        panel.backgroundColor = NSColor.white.withAlphaComponent(0.00001)
        panel.level = .screenSaver
        panel.contentView = NSHostingView(
            rootView: RadialMenuView(
                frontmostWindow: frontmostWindow,
                initialMousePosition: CGPoint(x: mouseX,
                                              y: mouseY)
            )
        )
        panel.alphaValue = 0
        panel.setFrame(
            CGRect(
                x: mouseX-windowSize/2,
                y: mouseY-windowSize/2,
                width: windowSize,
                height: windowSize
            ),
            display: false
        )
        panel.orderFrontRegardless()

        loopRadialMenuWindowController = .init(window: panel)

        NSAnimationContext.runAnimationGroup({ _ in
            panel.animator().alphaValue = 1
        })
    }

    private func closeRadialMenu() {
        guard let windowController = loopRadialMenuWindowController else { return }
        loopRadialMenuWindowController = nil

        windowController.window?.animator().alphaValue = 1
        NSAnimationContext.runAnimationGroup({ _ in
            windowController.window?.animator().alphaValue = 0
        }, completionHandler: {
            windowController.close()
        })
    }

    func addObservers() {
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged) { event -> Void in
            if event.keyCode == Defaults[.triggerKey] {
                if event.modifierFlags.rawValue == 256 {
                    self.closeLoop()
                } else {
                    self.openLoop()
                }
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(
                handleCurrentResizingDirectionChanged(
                    notification:
                )
            ),
            name: Notification.Name.currentDirectionChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(
                closeLoopFromNotification(
                    notification:
                )
            ),
            name: Notification.Name.closeLoop,
            object: nil
        )
    }

    @objc private func handleCurrentResizingDirectionChanged(notification: Notification) {
        if let direction = notification.userInfo?["Direction"] as? WindowDirection {
            currentResizingDirection = direction

            // Haptic feedback on the trackpad
            if self.isLoopRadialMenuShown {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    NSHapticFeedbackManager.FeedbackPattern.alignment,
                    performanceTime: NSHapticFeedbackManager.PerformanceTime.now
                )
            }
        }
    }

    @objc private func closeLoopFromNotification(notification: Notification) {
        if let forceClosed = notification.userInfo?["wasForceClosed"] as? Bool {
            self.closeLoop(wasForceClosed: forceClosed)
        }
    }

    private func openLoop() {
        // Loop will only open if accessibility access has been granted
        if accessibilityAccessManager.checkAccessibilityAccess() {
            frontmostWindow = windowEngine.getFrontmostWindow()

            if Defaults[.previewVisibility] == true && frontmostWindow != nil {
                loopPreview.showPreview()
            }
            showRadialMenu(frontmostWindow: frontmostWindow)

            radialMenuKeybindMonitor.start()

            isLoopRadialMenuShown = true
        }
    }

    private func closeLoop(wasForceClosed: Bool = false) {
        closeRadialMenu()
        loopPreview.closePreview()

        if frontmostWindow != nil &&
            wasForceClosed == false &&
            isLoopRadialMenuShown == true &&
            frontmostWindow != nil {

            windowEngine.resize(window: frontmostWindow!, direction: currentResizingDirection)

            Defaults[.timesLooped] += 1
        }

        radialMenuKeybindMonitor.stop()

        isLoopRadialMenuShown = false
        frontmostWindow = nil

        iconManager.checkIfUnlockedNewIcon()
    }
}
