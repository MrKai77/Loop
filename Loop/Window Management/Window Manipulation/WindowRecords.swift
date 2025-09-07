//
//  WindowRecords.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-23.
//

import SwiftUI

enum WindowRecords {
    private static var records: [WindowRecords.Record] = []

    struct Record {
        var cgWindowID: CGWindowID
        var initialFrame: CGRect
        var actionRecords: [WindowAction]
    }

    /// Has the window has been previously recorded?
    /// - Parameter window: The window to check
    /// - Returns: true or false
    static func hasBeenRecorded(_ window: Window) -> Bool {
        WindowRecords.records.contains { record in
            record.cgWindowID == window.cgWindowID
        }
    }

    /// The index of the window's record in the records array
    /// - Parameter window: Window to check
    /// - Returns: The index of the window's records
    private static func findRecordsID(for window: Window) -> Int? {
        if let id = WindowRecords.records.firstIndex(where: { $0.cgWindowID == window.cgWindowID }) {
            return id
        }

        return nil
    }

    /// This will erase ALL previous records of the window, and start a fresh new record for the selected window.
    /// - Parameter window: Window to record
    static func recordFirst(for window: Window) {
        WindowRecords.records.removeAll {
            $0.cgWindowID == window.cgWindowID
        }
        let frame = window.frame

        WindowRecords.records.append(
            WindowRecords.Record(
                cgWindowID: window.cgWindowID,
                initialFrame: frame,
                actionRecords: [.init(.initialFrame)]
            )
        )
    }

    /// Erase all previous records for a window
    /// - Parameter window: Window to erase
    static func eraseRecords(for window: Window) {
        WindowRecords.records.removeAll {
            $0.cgWindowID == window.cgWindowID
        }
    }

    /// Record a window's action in the records array
    /// - Parameters:
    ///   - window: Window to record
    ///   - action: WindowAction to record
    static func record(_ window: Window, _ action: WindowAction) {
        /// If the window has not been recorded, record it
        if !WindowRecords.hasBeenRecorded(window) {
            WindowRecords.recordFirst(for: window)
        }

        guard
            action.direction != .undo, // There is no point in recording undos
            let id = WindowRecords.findRecordsID(for: window)
        else {
            return
        }

        WindowRecords.records[id].actionRecords.insert(action, at: 0)
    }

    /// This window's last action
    /// - Parameters:
    ///   - window: Window to check
    /// - Returns: The window action
    static func getLastAction(for window: Window) -> WindowAction? {
        guard
            let id = WindowRecords.findRecordsID(for: window),
            WindowRecords.records[id].actionRecords.count > 1
        else {
            return nil
        }
        return WindowRecords.records[id].actionRecords[1]
    }

    /// This window's current recorded action
    /// - Parameters:
    ///   - window: Window to check
    /// - Returns: The window action
    static func getCurrentAction(for window: Window) -> WindowAction? {
        guard
            let id = WindowRecords.findRecordsID(for: window),
            WindowRecords.records[id].actionRecords.count > 1
        else {
            return nil
        }
        return WindowRecords.records[id].actionRecords[0]
    }

    static func removeLastAction(for window: Window) {
        guard
            let id = WindowRecords.findRecordsID(for: window),
            WindowRecords.records[id].actionRecords.count > 1
        else {
            return
        }

        WindowRecords.records[id].actionRecords.removeFirst()
    }

    static func getInitialFrame(for window: Window) -> CGRect? {
        guard let id = WindowRecords.findRecordsID(for: window) else {
            return nil
        }

        return WindowRecords.records[id].initialFrame
    }
}
