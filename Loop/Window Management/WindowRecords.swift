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

    static private func getIndex(of window: Window) -> Int? {
        guard WindowRecords.hasBeenRecorded(window),
              let idx = WindowRecords.records.firstIndex(where: { $0.cgWindowID == window.cgWindowID }) else {
            return nil
        }
        return idx
    }

    /// This will erase ALL previous records of the window, and start a fresh new record for the selected window.
    /// - Parameter window: The window to record
    static func recordFirst(for window: Window) {
        WindowRecords.records.removeAll(where: { $0.cgWindowID == window.cgWindowID })

        WindowRecords.records.append(
            WindowRecords.Record(
                cgWindowID: window.cgWindowID,
                initialFrame: window.frame,
                directionRecords: [.initialFrame]
            )
        )
    }

    static func recordDirection(_ window: Window, _ direction: WindowDirection) {
        guard let idx = WindowRecords.getIndex(of: window) else {
            return
        }

        WindowRecords.records[idx].directionRecords.insert(direction, at: 0)
    }

    static func hasBeenRecorded(_ window: Window) -> Bool {
        return WindowRecords.records.contains(where: { $0.cgWindowID == window.cgWindowID })
    }

    static func getLastDirection(for window: Window, willResize: Bool = false) -> WindowDirection {
        guard let idx = WindowRecords.getIndex(of: window),
                WindowRecords.records[idx].directionRecords.count > 1 else {
            return .noAction
        }

        let lastDirection = WindowRecords.records[idx].directionRecords[1]
        if willResize && WindowRecords.records[idx].directionRecords.count > 2 {
            WindowRecords.records[idx].directionRecords.removeFirst(2)
        }
        return lastDirection
    }

    static func getInitialFrame(for window: Window) -> CGRect? {
        guard let idx = WindowRecords.getIndex(of: window) else {
            return nil
        }

        return WindowRecords.records[idx].initialFrame
    }
}
