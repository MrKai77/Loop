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

    static func hasBeenRecorded(_ window: Window) -> Bool {
        return WindowRecords.records.contains(where: { record in
            return record.cgWindowID == window.cgWindowID && record.currentFrame == window.frame
        })
    }

    static private func findRecordsID(for window: Window) -> Int? {
        guard let id = WindowRecords.records.firstIndex(where: { $0.cgWindowID == window.cgWindowID }) else {
            return nil
        }
        return id
    }

    /// This will erase ALL previous records of the window, and start a fresh new record for the selected window.
    /// - Parameter window: The window to record
    static func recordFirst(for window: Window) {

        WindowRecords.records.removeAll(where: { $0.cgWindowID == window.cgWindowID })
        let frame = window.frame

        WindowRecords.records.append(
            WindowRecords.Record(
                cgWindowID: window.cgWindowID,
                initialFrame: frame,
                currentFrame: frame,
                directionRecords: [DirectionRecord(.initialFrame)]
            )
        )
    }

    static func recordDirection(_ window: Window, _ direction: WindowDirection, isCycling: Bool = false) {
        guard let id = WindowRecords.findRecordsID(for: window) else {
            return
        }

        WindowRecords.records[id].directionRecords.insert(DirectionRecord(direction, isCycling), at: 0)
        WindowRecords.records[id].currentFrame = window.frame
    }

    static func getLastDirection(
        for window: Window,
        willResize: Bool = false,
        offset: Int = 1,
        canBeCycling: Bool = false
    ) -> WindowDirection {
        guard let id = WindowRecords.findRecordsID(for: window),
                WindowRecords.records[id].directionRecords.count > offset else {
            return .noAction
        }
        let directionRecords = WindowRecords.records[id].directionRecords
        var lastDirection = directionRecords[offset]
        var actualOffset = offset

        while lastDirection.isCycling && !canBeCycling {
            actualOffset += 1
            lastDirection = directionRecords[actualOffset]
        }

        if willResize && WindowRecords.records[id].directionRecords.count > actualOffset + 1 {
            WindowRecords.records[id].directionRecords.removeFirst(actualOffset + 1)
        }

        return lastDirection.direction
    }

    static func getInitialFrame(for window: Window) -> CGRect? {
        guard let id = WindowRecords.findRecordsID(for: window) else {
            return nil
        }

        return WindowRecords.records[id].initialFrame
    }
}
