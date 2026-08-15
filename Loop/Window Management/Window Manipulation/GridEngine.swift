//
//  GridEngine.swift
//  Loop
//
//  Created for Loop Fork.
//

import AppKit
import Defaults

enum GridEngine {
    /// Snaps a window's position to the closest grid column/row intersection on the screen.
    static func snapMove(
        frame: CGRect,
        on screen: NSScreen,
        columns: Int = Defaults[.gridColumns],
        rows: Int = Defaults[.gridRows]
    ) -> CGRect {
        guard columns > 0, rows > 0 else { return frame }

        let screenBounds = screen.cgSafeScreenFrame
        let colWidth = screenBounds.width / CGFloat(columns)
        let rowHeight = screenBounds.height / CGFloat(rows)

        let relativeX = frame.minX - screenBounds.minX
        let relativeY = frame.minY - screenBounds.minY

        let snappedCol = round(relativeX / colWidth)
        let snappedRow = round(relativeY / rowHeight)

        let clampedCol = max(0, min(CGFloat(columns), snappedCol))
        let clampedRow = max(0, min(CGFloat(rows), snappedRow))

        let newX = screenBounds.minX + clampedCol * colWidth
        let newY = screenBounds.minY + clampedRow * rowHeight

        return CGRect(
            x: newX,
            y: newY,
            width: frame.width,
            height: frame.height
        )
    }

    /// Snaps both a window's origin and dimensions to grid increments.
    static func snapResize(
        frame: CGRect,
        on screen: NSScreen,
        columns: Int = Defaults[.gridColumns],
        rows: Int = Defaults[.gridRows]
    ) -> CGRect {
        guard columns > 0, rows > 0 else { return frame }

        let screenBounds = screen.cgSafeScreenFrame
        let colWidth = screenBounds.width / CGFloat(columns)
        let rowHeight = screenBounds.height / CGFloat(rows)

        let relativeX = frame.minX - screenBounds.minX
        let relativeY = frame.minY - screenBounds.minY

        let snappedCol = round(relativeX / colWidth)
        let snappedRow = round(relativeY / rowHeight)

        let newX = screenBounds.minX + max(0, min(CGFloat(columns - 1), snappedCol)) * colWidth
        let newY = screenBounds.minY + max(0, min(CGFloat(rows - 1), snappedRow)) * rowHeight

        let numCols = max(1, round(frame.width / colWidth))
        let numRows = max(1, round(frame.height / rowHeight))

        let maxAvailableCols = CGFloat(columns) - ((newX - screenBounds.minX) / colWidth)
        let maxAvailableRows = CGFloat(rows) - ((newY - screenBounds.minY) / rowHeight)

        let clampedCols = min(numCols, max(1, maxAvailableCols))
        let clampedRows = min(numRows, max(1, maxAvailableRows))

        let newWidth = clampedCols * colWidth
        let newHeight = clampedRows * rowHeight

        return CGRect(
            x: newX,
            y: newY,
            width: newWidth,
            height: newHeight
        )
    }
}
