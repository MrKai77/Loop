//
//  SpaceIndicatorController.swift
//  Loop
//
//  Created by Kai Azim on 2023-02-20.
//

import SwiftUI
import CoreGraphics

class SpaceIndicatorController {
    var loopSpacePreviewWindowController: NSWindowController?
    
    func setup() {
        self.showWindow()
        self.readActiveSpace()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.readActiveSpace), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }
    
    @objc func readActiveSpace() {
        let currentSpaceData = self.getSpace()
        NotificationCenter.default.post(name: Notification.Name.currentSpaceChanged,
                                        object: nil,
                                        userInfo: ["Active": currentSpaceData[0],
                                                   "Total": currentSpaceData[1]])
    }
    
    
    private let conn = _CGSDefaultConnection()
    func getSpace() -> [Int] {
        let displays = CGSCopyManagedDisplaySpaces(conn) as! [NSDictionary]
        let activeDisplay = CGSCopyActiveMenuBarDisplayIdentifier(conn) as! String
        let allSpaces: NSMutableArray = []
        var activeSpaceID = -1

        for display in displays {
            guard let current = display["Current Space"] as? [String: Any],
                  let spaces = display["Spaces"] as? [[String: Any]],
                  let displayID = display["Display Identifier"] as? String
                else {
                    continue
                }

            if (displayID == activeDisplay) {
                activeSpaceID = current["ManagedSpaceID"] as! Int
            }

            for space in spaces {
                let isFullscreen = space["TileLayoutManager"] as? [String: Any] != nil
                if isFullscreen {
                    continue
                }
                allSpaces.add(space)
            }
        }

        if (activeSpaceID != -1) {
            for (index, space) in allSpaces.enumerated() {
                let spaceID = (space as! NSDictionary)["ManagedSpaceID"] as! Int
                let spaceNumber = index + 1
                if spaceID == activeSpaceID {
                    return [spaceNumber, allSpaces.count]
                }
            }
        }
        return [0, 0]
    }
    
    func showWindow() {
        if let windowController = self.loopSpacePreviewWindowController {
            windowController.window?.orderFrontRegardless()
            return
        }
        
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: true,
                            screen: NSApp.keyWindow?.screen)
        panel.hasShadow = false
        panel.backgroundColor = NSColor.white.withAlphaComponent(0.00001)
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.contentView = NSHostingView(rootView: SpaceIndicatorView())
        panel.collectionBehavior = .canJoinAllSpaces
        panel.makeKeyAndOrderInFrontOfSpaces()
        
        guard let screen = NSScreen().screenWithMouse() else { return }
        let bounds = CGDisplayBounds(screen.displayID)
        let menubarHeight = NSApp.mainMenu?.menuBarHeight ?? 0
        
        let screenWidth = bounds.width
        let screenHeight = bounds.height - menubarHeight
        let screenOriginX = bounds.origin.x
        let screenOriginY = bounds.origin.y
        
        panel.setFrame(NSRect(x: screenOriginX,
                              y: screenOriginY,
                              width: screenWidth,
                              height: screenHeight), display: false)
        
        self.loopSpacePreviewWindowController = .init(window: panel)
    }
}
