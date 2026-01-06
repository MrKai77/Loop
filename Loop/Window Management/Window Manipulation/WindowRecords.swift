//
//  WindowRecords.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-23.
//

import SwiftUI
import Scribe

enum WindowRecords {
    private static var recordsByWindowID: [CGWindowID: WindowRecords.Record] = [:]

    struct Record {
        let initialFrame: CGRect
        var actions: [WindowAction]
        
        init(initialFrame: CGRect) {
            self.initialFrame = initialFrame
            self.actions = [.init(.initialFrame)]
        }
    }

    /// Has the window has been previously recorded?
    /// - Parameter window: The window to check
    /// - Returns: true or false
    static func hasBeenRecorded(_ window: Window) -> Bool {
        recordsByWindowID[window.cgWindowID] != nil
    }

    /// This will erase ALL previous records of the window, and start a fresh new record for the selected window.
    /// - Parameter window: Window to record
    static func recordFirst(for window: Window, ignoreIfRecordAlreadyExists: Bool) {
        guard !ignoreIfRecordAlreadyExists || recordsByWindowID[window.cgWindowID] == nil else {
            Log.info("Not erasing existing records for window: \(window)", category: .windowRecords)
            return
        }
        
        eraseRecords(for: window)

        let frame = window.frame
        recordsByWindowID[window.cgWindowID] = Record(initialFrame: frame)
        
        Log.info("Recorded first for: \(window)", category: .windowRecords)
    }

    /// Erase all previous records for a window
    /// - Parameter window: Window to erase
    static func eraseRecords(for window: Window) {
        recordsByWindowID[window.cgWindowID] = nil
        Log.success("Erased records for: \(window)", category: .windowRecords)
    }

    /// Record a window's action in the records array
    /// - Parameters:
    ///   - window: Window to record
    ///   - action: WindowAction to record
    static func record(_ window: Window, _ action: WindowAction) {
        /// If the window has not been recorded, record it
        recordFirst(for: window, ignoreIfRecordAlreadyExists: true)

        // There is no point in recording undo
        guard action.direction != .undo else {
            return
        }

        recordsByWindowID[window.cgWindowID]?.actions.insert(action, at: 0)
        
        Log.info("Recorded: \(action) for: \(window)", category: .windowRecords)
    }
    
    /// Removes the last action performed on the specified window. This will NOT remove the first action for the specified window.
    static func removeLastAction(for window: Window) {
        guard let record = recordsByWindowID[window.cgWindowID],
              record.actions.count > 1
        else {
            Log.info("Skipped removing last record for: \(window)", category: .windowRecords)
            return
        }

        recordsByWindowID[window.cgWindowID]?.actions.removeFirst()
        
        Log.info("Removed last record for: \(window)", category: .windowRecords)
    }

    /// This window's last action
    /// - Parameters:
    ///   - window: Window to check
    /// - Returns: The window action
    static func getLastAction(for window: Window) -> WindowAction? {
        guard let record = recordsByWindowID[window.cgWindowID],
              record.actions.count >= 2
        else {
            return nil
        }

        return record.actions[1]
    }

    /// This window's current recorded action
    /// - Parameters:
    ///   - window: Window to check
    /// - Returns: The window action
    static func getCurrentAction(for window: Window) -> WindowAction? {
        guard let record = recordsByWindowID[window.cgWindowID],
              record.actions.count >= 1
        else {
            return nil
        }
        
        return record.actions[0]
    }

    static func getInitialFrame(for window: Window) -> CGRect? {
        recordsByWindowID[window.cgWindowID]?.initialFrame
    }
}
