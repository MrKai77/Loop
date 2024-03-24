//
//  WindowRecords.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-23.
//

import SwiftUI

struct WindowRecords {
    static private var records: [WindowRecords.Record] = []

    struct Record {
        var cgWindowID: CGWindowID
        var initialFrame: CGRect
        var currentFrame: CGRect
        var actionRecords: [WindowAction]
    }

    /// Has the window has been previously recorded?
    /// - Parameter window: The window to check
    /// - Returns: true or false
    static func hasBeenRecorded(_ window: Window) -> Bool {
        return WindowRecords.records.contains(where: { record in
            return record.cgWindowID == window.cgWindowID &&
                   record.currentFrame.approximatelyEqual(to: window.frame)
        })
    }

    /// The index of the window's record in the records array
    /// - Parameter window: Window to check
    /// - Returns: The index of the window's records
    static private func findRecordsID(for window: Window) -> Int? {
        guard let id = WindowRecords.records.firstIndex(where: { $0.cgWindowID == window.cgWindowID }) else {
            return nil
        }
        return id
    }

    /// This will erase ALL previous records of the window, and start a fresh new record for the selected window.
    /// - Parameter window: Window to record
    static func recordFirst(for window: Window) {

        WindowRecords.records.removeAll(where: { $0.cgWindowID == window.cgWindowID })
        let frame = window.frame

        WindowRecords.records.append(
            WindowRecords.Record(
                cgWindowID: window.cgWindowID,
                initialFrame: frame,
                currentFrame: frame,
                actionRecords: [.init(.initialFrame)]
            )
        )
    }

    /// Erase all previous records for a window
    /// - Parameter window: Window to erase
    static func eraseRecords(for window: Window) {
        WindowRecords.records.removeAll(where: { $0.cgWindowID == window.cgWindowID })
    }

    /// Record a window's action in the records array
    /// - Parameters:
    ///   - window: Window to record
    ///   - action: WindowAction to record
    static func record(_ window: Window, _ action: WindowAction) {
        guard let id = WindowRecords.findRecordsID(for: window) else {
            return
        }

        WindowRecords.records[id].actionRecords.insert(action, at: 0)
        WindowRecords.records[id].currentFrame = window.frame
    }

    /// What was this window's last action?
    /// - Parameters:
    ///   - window: Window to check
    ///   - willResize: Will we resize the window after this function? If so, we will also remove the last direction.
    ///   - offset: Which "last action" do we want? 1 means the last one, 2 means the one before the last one etc.
    /// - Returns: The window action
    static func getLastAction(
        for window: Window,
        willResize: Bool = false,
        offset: Int = 1
    ) -> WindowAction? {
        guard 
            let id = WindowRecords.findRecordsID(for: window),
            WindowRecords.records[id].actionRecords.count > offset
        else {
            return nil
        }

        let lastDirection = WindowRecords.records[id].actionRecords[offset]

        if willResize && WindowRecords.records[id].actionRecords.count > offset + 1 {
            WindowRecords.records[id].actionRecords.removeFirst(offset + 1)
        }

        return lastDirection
    }

    static func getInitialFrame(for window: Window) -> CGRect? {
        guard let id = WindowRecords.findRecordsID(for: window) else {
            return nil
        }

        return WindowRecords.records[id].initialFrame
    }
}
