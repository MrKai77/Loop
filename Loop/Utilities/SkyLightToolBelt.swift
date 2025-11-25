//
//  SkyLightToolBelt.swift
//  Loop
//
//  Created by Kai Azim on 2025-11-24.
//

import SwiftUI

enum SkyLightToolBelt {
    ///
    /// Focuses a window. This will attempt to bring the window to the front and make it the active window.
    /// Note that this first sets the process as frontmost, *then* sends a left click event to the window itself.
    ///
    /// This method uses a private API to focus the window.
    /// The code for this method is derived from the Amethyst source code. Details of its implementation can be found [here](https://github.com/Hammerspoon/hammerspoon/issues/370#issuecomment-545545468)
    ///
    /// - Parameters:
    ///   - windowID: The `CGWindowID` of the window to focus.
    ///   - pid: The PID of the target window's owner process.
    /// - Returns: Whether this operation was successful.
    @discardableResult
    static func focusWindow(windowID: CGWindowID, pid: pid_t) -> OSStatus {
        var wid = windowID
        var psn = ProcessSerialNumber()
        let status = GetProcessForPID(pid, &psn)

        guard status == noErr else {
            return status
        }

        var cgStatus = SLPSSetFrontProcessWithOptions(
            &psn,
            wid,
            kCPSUserGenerated
        )

        guard cgStatus == .success else {
            return cgStatus.rawValue
        }

        /// `0x01` is left click down, `0x02` is left click up (see `CGEventType`)
        for byte in [0x01, 0x02] {
            /// Create raw `SLSEvent` data.
            /// Future consideration: instead of manually creating the bytes here, investigate:
            /// - Creating a `SLSEvent` (likely analogous to `CGEvent`)
            /// - Apply an identifier to the event to help Loop differentiate events that originate from itself
            /// - Converting the `SLSEvent` to data using `SLEventCreateData` in SkyLight
            var bytes = [UInt8](repeating: 0, count: 0xF8)
            bytes[0x04] = 0xF8
            bytes[0x08] = UInt8(byte)
            bytes[0x3A] = 0x10
            memcpy(&bytes[0x3C], &wid, MemoryLayout<UInt32>.size)
            memset(&bytes[0x20], 0xFF, 0x10)
            cgStatus = bytes.withUnsafeMutableBufferPointer { pointer in
                SLPSPostEventRecordTo(&psn, &pointer.baseAddress!.pointee)
            }

            guard cgStatus == .success else {
                return cgStatus.rawValue
            }
        }

        return cgStatus.rawValue
    }

    /// Sets the background blur radius of a window.
    /// - Parameters:
    ///   - windowID: The `CGWindowID` of the window to manipulate.
    ///   - radius: The desired blur radius.
    /// - Returns: Whether this operation was successful.
    @discardableResult
    static func setBackgroundBlur(windowID: CGWindowID, radius: Int) -> OSStatus {
        let cid = SLSDefaultConnectionForThread()
        let status = SLSSetWindowBackgroundBlurRadius(
            cid,
            windowID,
            radius
        )

        return status
    }

    /// Captures images for each of the windows that are passed in.
    /// - Parameter windowIDs: The `CGWindowID`s for each of the windows to capture.
    /// - Returns: An array of `CGImage`s for each window, in the same order as the windows that were passed in.
    static func captureWindowList(windowIDs: [CGWindowID]) -> [CGImage] {
        var captureWindowIDs = windowIDs

        let cid = SLSMainConnectionID()
        let images = SLSHWCaptureWindowList(
            cid,
            &captureWindowIDs,
            captureWindowIDs.count,
            [.ignoreGlobalClipShape, .bestResolution, .fullSize]
        ).takeRetainedValue() as! [CGImage]

        return images
    }

    /// Retrieves the corner radii for a specific window.
    /// - Parameter windowID: The `CGWindowID` of the window
    /// - Returns: The corner radii of the window if the operation was successful, or `nil` otherwise.
    static func getCornerRadii(windowID: CGWindowID) -> RectangleCornerRadii? {
        let windowIDsCFArray: CFArray = [windowID] as CFArray

        let cid = SLSMainConnectionID()
        let query = SLSWindowQueryWindows(cid, windowIDsCFArray, 0)
        let iterator = SLSWindowQueryResultCopyWindows(query)

        while SLSWindowIteratorAdvance(iterator) {
            guard checkIfWindowIsValid(iterator), SLSWindowIteratorGetWindowID(iterator) == windowID else {
                continue
            }

            guard let cornerRadii = SLSWindowIteratorGetResolvedCornerRadii(iterator, windowID) as? [CGFloat],
                  cornerRadii.count == 4
            else {
                return nil
            }

            return RectangleCornerRadii(
                topLeading: cornerRadii[0],
                bottomLeading: cornerRadii[3],
                bottomTrailing: cornerRadii[2],
                topTrailing: cornerRadii[1]
            )
        }

        return nil
    }

    /// Checks if the current window in a `SLSWindowIterator` is valid for Loop to use.
    /// - Parameter iterator: The `SLSWindowIterator` object
    /// - Returns: Whether this window is valid.
    private static func checkIfWindowIsValid(_ iterator: CFTypeRef) -> Bool {
        let parentWindowID: CGWindowID = SLSWindowIteratorGetParentID(iterator)

        guard parentWindowID == 0 else {
            return false
        }

        let tags: SLSWindowTags = SLSWindowIteratorGetTags(iterator)
        let attributes: UInt64 = SLSWindowIteratorGetAttributes(iterator)

        // Currently known what 0x2 and 0x400_0000_0000_0000 are.
        if (attributes & 0x2) != 0 || (tags.rawValue & 0x400_0000_0000_0000) != 0,
           tags.contains(.document) || (tags.contains(.floating) && tags.contains(.modal)) {
            return true
        }

        return false
    }
}

// MARK: - SkyLight Private APIs

typealias SLSConnectionID = UInt32

@_silgen_name("SLSMainConnectionID")
func SLSMainConnectionID() -> SLSConnectionID

@_silgen_name("SLSDefaultConnectionForThread")
func SLSDefaultConnectionForThread() -> SLSConnectionID

@_silgen_name("SLSWindowQueryWindows")
func SLSWindowQueryWindows(
    _ cid: SLSConnectionID,
    _ windows: CFArray?,
    _ count: UInt32
) -> CFTypeRef

@_silgen_name("SLSWindowQueryResultCopyWindows")
func SLSWindowQueryResultCopyWindows(_ query: CFTypeRef) -> CFTypeRef

@_silgen_name("SLSWindowIteratorGetCount")
func SLSWindowIteratorGetCount(_ iterator: CFTypeRef) -> Int

@_silgen_name("SLSWindowIteratorAdvance")
func SLSWindowIteratorAdvance(_ iterator: CFTypeRef) -> Bool

@_silgen_name("SLSWindowIteratorGetWindowID")
func SLSWindowIteratorGetWindowID(_ iterator: CFTypeRef) -> CGWindowID

@_silgen_name("SLSWindowIteratorGetParentID")
func SLSWindowIteratorGetParentID(_ iterator: CFTypeRef) -> CGWindowID

@_silgen_name("SLSWindowIteratorGetTags")
func SLSWindowIteratorGetTags(_ iterator: CFTypeRef) -> SLSWindowTags

struct SLSWindowTags: OptionSet {
    let rawValue: UInt64

    static let document = Self(rawValue: 1 << 0)
    static let floating = Self(rawValue: 1 << 1)
    static let attached = Self(rawValue: 1 << 7)
    static let sticky = Self(rawValue: 1 << 11)
    static let ignoresCycle = Self(rawValue: 1 << 18)
    static let modal = Self(rawValue: 1 << 31)
}

@_silgen_name("SLSWindowIteratorGetAttributes")
func SLSWindowIteratorGetAttributes(_ iterator: CFTypeRef) -> UInt64

/// All four corner radii values returned in the array will be identical to each other, as seen in: https://gist.github.com/MrKai77/654975cc2a35cfa5328a7c0a90a01fde
@_silgen_name("SLSWindowIteratorGetResolvedCornerRadii")
func SLSWindowIteratorGetResolvedCornerRadii(_ iterator: CFTypeRef, _ wid: UInt32) -> CFArray

@_silgen_name("SLSSetWindowBackgroundBlurRadius") @discardableResult
func SLSSetWindowBackgroundBlurRadius(
    _ connection: SLSConnectionID,
    _ wid: CGWindowID,
    _ radius: Int
) -> OSStatus

@_silgen_name("SLSHWCaptureWindowList")
func SLSHWCaptureWindowList(
    _ cid: SLSConnectionID,
    _ windowList: UnsafeMutablePointer<CGWindowID>,
    _ windowCount: Int,
    _ options: SLSWindowCaptureOptions
) -> Unmanaged<CFArray>

struct SLSWindowCaptureOptions: OptionSet {
    let rawValue: UInt32

    static let ignoreGlobalClipShape = Self(rawValue: 1 << 11)

    // On a retina display, this captures at 1 pt : 4 px
    static let nominalResolution = Self(rawValue: 1 << 9)

    // Captures at 1 pt : 1px
    static let bestResolution = Self(rawValue: 1 << 8)

    // When Stage Manager is enabled, screenshots can become skewed. This param gets us full-size screenshots regardless
    static let fullSize = Self(rawValue: 1 << 19)
}

@_silgen_name("_SLPSSetFrontProcessWithOptions") @discardableResult
func SLPSSetFrontProcessWithOptions(
    _ psn: inout ProcessSerialNumber,
    _ wid: UInt32,
    _ mode: UInt32
) -> CGError

@_silgen_name("SLPSPostEventRecordTo") @discardableResult
func SLPSPostEventRecordTo(
    _ psn: inout ProcessSerialNumber,
    _ bytes: inout UInt8
) -> CGError

let kCPSUserGenerated: UInt32 = 0x200

@_silgen_name("GetProcessForPID") @discardableResult
func GetProcessForPID(
    _ pid: pid_t,
    _ psn: inout ProcessSerialNumber
) -> OSStatus
