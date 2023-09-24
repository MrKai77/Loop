//
//  WindowRecords.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-23.
//

import SwiftUI

struct WindowRecords {
    static private var records: [WindowRecords.Record] = []

    private struct Record {
        var cgWindowID: CGWindowID
        var initialFrame: CGRect
        var directionRecords: [WindowDirection]
    }

    /// This will erase ALL previous records of the window, and start a fresh new record for the selected window.
    /// - Parameter window: The window to record
    static func recordFirst(for window: Window) {
        WindowRecords.records.removeAll(where: { $0.cgWindowID == window.cgWindowID })

        WindowRecords.records.append(
            WindowRecords.Record(
                cgWindowID: window.cgWindowID,
                initialFrame: window.frame,
                directionRecords: [.noAction]
            )
        )
    }

    static func recordDirection(_ window: Window, _ direction: WindowDirection) {
        guard WindowRecords.hasBeenRecorded(window),
              let idx = WindowRecords.records.firstIndex(where: { $0.cgWindowID == window.cgWindowID }) else {
            return
        }

        WindowRecords.records[idx].directionRecords.insert(direction, at: 0)
    }

    static func hasBeenRecorded(_ window: Window) -> Bool {
        return WindowRecords.records.contains(where: { $0.cgWindowID == window.cgWindowID })
    }

    static func getLastDirection(for window: Window) -> WindowDirection {
        guard WindowRecords.hasBeenRecorded(window),
              let idx = WindowRecords.records.firstIndex(where: { $0.cgWindowID == window.cgWindowID }) else {
            return .noAction
        }

        return WindowRecords.records[idx].directionRecords[1]
    }
}
