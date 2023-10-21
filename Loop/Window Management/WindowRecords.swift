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
        var directionRecords: [DirectionRecord]
    }

    struct DirectionRecord {
        init(_ direction: WindowDirection, _ isCycling: Bool = false) {
            self.direction = direction
            self.isCycling = isCycling
        }

        var direction: WindowDirection
        var isCycling: Bool
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
                directionRecords: [DirectionRecord(.initialFrame)]
            )
        )
    }

    static func recordDirection(_ window: Window, _ direction: WindowDirection, isCycling: Bool = false) {
        guard let idx = WindowRecords.getIndex(of: window) else {
            return
        }

        WindowRecords.records[idx].directionRecords.insert(DirectionRecord(direction, isCycling), at: 0)
    }

    static func hasBeenRecorded(_ window: Window) -> Bool {
        return WindowRecords.records.contains(where: { $0.cgWindowID == window.cgWindowID })
    }

    static func getLastDirection(
        for window: Window,
        willResize: Bool = false,
        offset: Int = 1,
        canBeCycling: Bool = false
    ) -> WindowDirection {
        guard let idx = WindowRecords.getIndex(of: window),
                WindowRecords.records[idx].directionRecords.count > offset else {
            return .noAction
        }
        let directionRecords = WindowRecords.records[idx].directionRecords
        var lastDirection = directionRecords[offset]
        var actualOffset = offset

        while lastDirection.isCycling && !canBeCycling {
            actualOffset += 1
            lastDirection = directionRecords[actualOffset]
        }

        if willResize && WindowRecords.records[idx].directionRecords.count > actualOffset + 1 {
            WindowRecords.records[idx].directionRecords.removeFirst(actualOffset + 1)
        }

        return lastDirection.direction
    }

    static func getInitialFrame(for window: Window) -> CGRect? {
        guard let idx = WindowRecords.getIndex(of: window) else {
            return nil
        }

        return WindowRecords.records[idx].initialFrame
    }
}
