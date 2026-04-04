//
//  SkyLightToolBelt.swift
//  Loop
//
//  Created by Kai Azim on 2025-11-24.
//

import Scribe
import SwiftUI

/// A wrapper for functions defined in `SkyLightSymbolLoader`
@Loggable(style: .static)
enum SkyLightToolBelt {
    /// Brings the window’s owning process to the front using SkyLight APIs.
    /// - Parameters:
    ///   - windowID: The `CGWindowID` of the window to make the frontmost process.
    ///   - pid: The PID of the target window's owner process.
    /// - Returns: Whether this operation was successful.
    static func makeFrontProcess(windowID: CGWindowID, pid: pid_t) -> Bool {
        guard let SLPSSetFrontProcessWithOptions = SkyLightSymbolLoader.SLPSSetFrontProcessWithOptions else {
            log.error("Failed to load SkyLight symbols in \(#function)")
            return false
        }

        var psn = ProcessSerialNumber()
        let status = GetProcessForPID(pid, &psn)

        guard status == noErr else {
            log.error("Failed to get PSN: \(status)")
            return false
        }

        let cgStatus = SLPSSetFrontProcessWithOptions(
            &psn,
            windowID,
            kCPSUserGenerated
        )

        guard cgStatus == .success else {
            log.error("Failed to set frontmost process with status: \(cgStatus.rawValue)")
            return false
        }

        return true
    }

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
    static func makeKeyWindow(windowID: CGWindowID, pid: pid_t) -> Bool {
        guard let SLPSPostEventRecordTo = SkyLightSymbolLoader.SLPSPostEventRecordTo else {
            log.error("Failed to load SkyLight symbols in \(#function)")
            return false
        }

        var wid = windowID
        var psn = ProcessSerialNumber()
        let status = GetProcessForPID(pid, &psn)

        guard status == noErr else {
            log.error("Failed to get PSN: \(status)")
            return false
        }

        // `0x01` is left click down, `0x02` is left click up (see `CGEventType`)
        for byte in [0x01, 0x02] {
            // Create raw `SLSEvent` data.
            // Future consideration: instead of manually creating the bytes here, investigate:
            // - Creating a `SLSEvent` (likely analogous to `CGEvent`)
            // - Apply an identifier to the event to help Loop differentiate events that originate from itself
            // - Converting the `SLSEvent` to data using `SLEventCreateData` in SkyLight
            var bytes = [UInt8](repeating: 0, count: 0xF8)
            bytes[0x04] = 0xF8
            bytes[0x08] = UInt8(byte)
            bytes[0x3A] = 0x10
            memcpy(&bytes[0x3C], &wid, MemoryLayout<UInt32>.size)
            memset(&bytes[0x20], 0xFF, 0x10)
            let cgStatus = bytes.withUnsafeMutableBufferPointer { pointer in
                SLPSPostEventRecordTo(&psn, &pointer.baseAddress!.pointee)
            }

            guard cgStatus == .success else {
                log.error("Failed to click frontmost process with status: \(cgStatus.rawValue)")
                return false
            }
        }

        return true
    }

    /// Sets the background blur radius of a window.
    /// - Parameters:
    ///   - windowID: The `CGWindowID` of the window to manipulate.
    ///   - radius: The desired blur radius.
    /// - Returns: Whether this operation was successful.
    static func setBackgroundBlur(windowID: CGWindowID, radius: Int) {
        guard let SLSDefaultConnectionForThread = SkyLightSymbolLoader.SLSDefaultConnectionForThread,
              let SLSSetWindowBackgroundBlurRadius = SkyLightSymbolLoader.SLSSetWindowBackgroundBlurRadius
        else {
            log.error("Failed to load SkyLight symbols in \(#function)")
            return
        }

        let cid = SLSDefaultConnectionForThread()
        let status = SLSSetWindowBackgroundBlurRadius(
            cid,
            windowID,
            radius
        )

        if status != noErr {
            log.error("Failed to set window background blur radius")
        }
    }

    /// Captures images for each of the windows that are passed in.
    /// - Parameter windowIDs: The `CGWindowID`s for each of the windows to capture.
    /// - Returns: An array of `CGImage`s for each window, in the same order as the windows that were passed in.
    static func captureWindowList(windowIDs: [CGWindowID]) -> [CGImage] {
        guard let SLSMainConnectionID = SkyLightSymbolLoader.SLSMainConnectionID,
              let SLSHWCaptureWindowList = SkyLightSymbolLoader.SLSHWCaptureWindowList
        else {
            log.error("Failed to load SkyLight symbols in \(#function)")
            return []
        }

        var captureWindowIDs = windowIDs
        let options: SLSWindowCaptureOptions = [.ignoreGlobalClipShape, .bestResolution, .fullSize]

        let cid = SLSMainConnectionID()
        let images = SLSHWCaptureWindowList(
            cid,
            &captureWindowIDs,
            captureWindowIDs.count,
            options.rawValue
        ).takeRetainedValue() as! [CGImage]

        return images
    }

    /// Retrieves the corner radii for a specific window.
    /// - Parameter windowID: The `CGWindowID` of the window
    /// - Returns: The corner radii of the window if the operation was successful, or `nil` otherwise.
    @available(macOS 26.0, *)
    static func getCornerRadii(windowID: CGWindowID) -> RectangleCornerRadii? {
        guard let SLSMainConnectionID = SkyLightSymbolLoader.SLSMainConnectionID,
              let SLSWindowQueryWindows = SkyLightSymbolLoader.SLSWindowQueryWindows,
              let SLSWindowQueryResultCopyWindows = SkyLightSymbolLoader.SLSWindowQueryResultCopyWindows,
              let SLSWindowIteratorAdvance = SkyLightSymbolLoader.SLSWindowIteratorAdvance,
              let SLSWindowIteratorGetWindowID = SkyLightSymbolLoader.SLSWindowIteratorGetWindowID,
              let SLSWindowIteratorGetResolvedCornerRadii = SkyLightSymbolLoader.SLSWindowIteratorGetResolvedCornerRadii
        else {
            log.error("Failed to load SkyLight symbols in \(#function)")
            return nil
        }

        let windowIDsCFArray: CFArray = [windowID] as CFArray

        let cid = SLSMainConnectionID()
        let query = SLSWindowQueryWindows(cid, windowIDsCFArray, 0)
        let iterator = SLSWindowQueryResultCopyWindows(query)

        while SLSWindowIteratorAdvance(iterator) {
            guard checkIfWindowIsValid(iterator), SLSWindowIteratorGetWindowID(iterator) == windowID else {
                continue
            }

            guard let cornerRadii = SLSWindowIteratorGetResolvedCornerRadii(iterator, windowID).takeRetainedValue() as? [CGFloat],
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

    /// Forces the system to re-resolve icon appearance variants by flushing the Dock's icon cache.
    /// Re-saves the current `SLSIconAppearanceConfiguration`, causing the Dock to re-read the
    /// bundle's `.icon` file (which supports light/dark/clear variants).
    /// https://www.granola.ai/blog/so-you-think-its-easy-to-change-an-app-icon
    static func refreshIconAppearanceCache() {
        guard let cls = NSClassFromString("SLSIconAppearanceConfiguration") as? NSObject.Type else {
            log.error("SLSIconAppearanceConfiguration class not found")
            return
        }

        let fetchSelector = NSSelectorFromString("fetchCurrentIconAppearanceConfiguration")
        guard cls.responds(to: fetchSelector),
              let config = cls.perform(fetchSelector)?.takeUnretainedValue() as? NSObject else {
            log.error("Failed to fetch icon appearance configuration")
            return
        }

        let saveSelector = NSSelectorFromString("save")
        guard config.responds(to: saveSelector) else {
            log.error("Icon appearance configuration does not respond to save")
            return
        }

        config.perform(saveSelector)
    }

    /// Checks if the current window in a `SLSWindowIterator` is valid for Loop to use.
    /// - Parameter iterator: The `SLSWindowIterator` object
    /// - Returns: Whether this window is valid.
    private static func checkIfWindowIsValid(_ iterator: CFTypeRef) -> Bool {
        guard let SLSWindowIteratorGetParentID = SkyLightSymbolLoader.SLSWindowIteratorGetParentID,
              let SLSWindowIteratorGetTags = SkyLightSymbolLoader.SLSWindowIteratorGetTags,
              let SLSWindowIteratorGetAttributes = SkyLightSymbolLoader.SLSWindowIteratorGetAttributes
        else {
            log.error("Failed to load SkyLight symbols in \(#function)")
            return false
        }

        let parentWindowID: CGWindowID = SLSWindowIteratorGetParentID(iterator)

        guard parentWindowID == 0 else {
            return false
        }

        let tags = SLSWindowTags(rawValue: SLSWindowIteratorGetTags(iterator))
        let attributes: UInt32 = SLSWindowIteratorGetAttributes(iterator)

        // Currently known what 0x2 and 0x400_0000_0000_0000 are.
        if (attributes & 0x2) != 0 || (tags.rawValue & 0x400_0000_0000_0000) != 0,
           tags.contains(.document) || (tags.contains(.floating) && tags.contains(.modal)) {
            return true
        }

        return false
    }
}
