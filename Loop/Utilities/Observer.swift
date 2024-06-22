//
//  Observer.swift
//  Loop
//
//  Created by Kai Azim on 2024-06-21.
//
// Mostly taken from https://github.com/tmandry/AXSwift/, thank you so much :)

import Cocoa
import Darwin
import Foundation

/// Observers watch for events on an application's UI elements.
///
/// Events are received as part of the application's default run loop.
class Observer {
    typealias Callback = (
        _ observer: Observer,
        _ window: Window,
        _ notification: AXNotification
    ) -> ()

    typealias CallbackWithInfo = (
        _ observer: Observer,
        _ window: Window,
        _ notification: AXNotification,
        _ info: [String: AnyObject]?
    ) -> ()

    let pid: pid_t
    let axObserver: AXObserver!
    let callback: Callback?
    let callbackWithInfo: CallbackWithInfo?

//    public fileprivate(set) lazy var application: Application = Application(forKnownProcessID: self.pid)!

    /// Creates and starts an observer on the given `processID`.
    public init(processID: pid_t, callback: @escaping Callback) throws {
        var axObserver: AXObserver?
        let error = AXObserverCreate(processID, internalCallback, &axObserver)

        self.pid = processID
        self.axObserver = axObserver
        self.callback = callback
        self.callbackWithInfo = nil

        guard error == .success else {
            throw error
        }
        assert(axObserver != nil)

        start()
    }

    /// Creates and starts an observer on the given `processID`.
    ///
    /// Use this initializer if you want the extra user info provided with notifications.
    public init(processID: pid_t, callback: @escaping CallbackWithInfo) throws {
        var axObserver: AXObserver?
        let error = AXObserverCreateWithInfoCallback(processID, internalInfoCallback, &axObserver)

        self.pid = processID
        self.axObserver = axObserver
        self.callback = nil
        self.callbackWithInfo = callback

        guard error == .success else {
            throw error
        }
        assert(axObserver != nil)

        start()
    }

    deinit {
        stop()
    }

    /// Starts watching for events. You don't need to call this method unless you use `stop()`.
    ///
    /// If the observer has already been started, this method does nothing.
    public func start() {
        CFRunLoopAddSource(
            RunLoop.current.getCFRunLoop(),
            AXObserverGetRunLoopSource(axObserver),
            CFRunLoopMode.defaultMode
        )
    }

    /// Stops sending events to your callback until the next call to `start`.
    ///
    /// If the observer has already been started, this method does nothing.
    ///
    /// - important: Events will still be queued in the target process until the Observer is started
    ///              again or destroyed. If you don't want them, create a new Observer.
    public func stop() {
        CFRunLoopRemoveSource(
            RunLoop.current.getCFRunLoop(),
            AXObserverGetRunLoopSource(axObserver),
            CFRunLoopMode.defaultMode
        )
    }

    /// Adds a notification for the observer to watch.
    ///
    /// - parameter notification: The name of the notification to watch for.
    /// - parameter forElement: The element to watch for the notification on. Must belong to the
    ///                         application this observer was created on.
    /// - note: The underlying API returns an error if the notification is already added, but that
    ///         error is not passed on for consistency with `start()` and `stop()`.
    /// - throws: `Error.NotificationUnsupported`: The element does not support notifications (note
    ///           that the system-wide element does not support notifications).
    public func addNotification(
        _ notification: AXNotification,
        forElement element: Window
    ) throws {
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let error = AXObserverAddNotification(
            axObserver, element.axWindow, notification.rawValue as CFString, selfPtr
        )
        guard error == .success || error == .notificationAlreadyRegistered else {
            throw error
        }
    }

    /// Removes a notification from the observer.
    ///
    /// - parameter notification: The name of the notification to stop watching.
    /// - parameter forElement: The element to stop watching the notification on.
    /// - note: The underlying API returns an error if the notification is not present, but that
    ///         error is not passed on for consistency with `start()` and `stop()`.
    /// - throws: `Error.NotificationUnsupported`: The element does not support notifications (note
    ///           that the system-wide element does not support notifications).
    public func removeNotification(
        _ notification: AXNotification,
        forElement element: Window
    ) throws {
        let error = AXObserverRemoveNotification(
            axObserver, element.axWindow, notification.rawValue as CFString
        )
        guard error == .success || error == .notificationNotRegistered else {
            throw error
        }
    }
}

private func internalCallback(
    _: AXObserver,
    axElement: AXUIElement,
    notification: CFString,
    userData: UnsafeMutableRawPointer?
) {
    guard let userData else { fatalError("userData should be an AXSwift.Observer") }
    guard let element = try? Window(element: axElement) else { return }

    let observer = Unmanaged<Observer>.fromOpaque(userData).takeUnretainedValue()
    guard let notif = AXNotification(rawValue: notification as String) else {
        NSLog("Unknown AX notification %s received", notification as String)
        return
    }
    observer.callback!(observer, element, notif)
}

private func internalInfoCallback(
    _: AXObserver,
    axElement: AXUIElement,
    notification: CFString,
    cfInfo: CFDictionary,
    userData: UnsafeMutableRawPointer?
) {
    guard let userData else { fatalError("userData should be an AXSwift.Observer") }
    guard let element = try? Window(element: axElement) else { return }

    let observer = Unmanaged<Observer>.fromOpaque(userData).takeUnretainedValue()
    let info = cfInfo as NSDictionary? as! [String: AnyObject]?
    guard let notif = AXNotification(rawValue: notification as String) else {
        NSLog("Unknown AX notification %s received", notification as String)
        return
    }
    observer.callbackWithInfo!(observer, element, notif, info)
}

public enum AXNotification: String {
    // Focus notifications
    case mainWindowChanged = "AXMainWindowChanged"
    case focusedWindowChanged = "AXFocusedWindowChanged"
    case focusedUIElementChanged = "AXFocusedUIElementChanged"
    case focusedTabChanged = "AXFocusedTabChanged"

    // Application notifications
    case applicationActivated = "AXApplicationActivated"
    case applicationDeactivated = "AXApplicationDeactivated"
    case applicationHidden = "AXApplicationHidden"
    case applicationShown = "AXApplicationShown"

    // Window notifications
    case windowCreated = "AXWindowCreated"
    case windowMoved = "AXWindowMoved"
    case windowResized = "AXWindowResized"
    case windowMiniaturized = "AXWindowMiniaturized"
    case windowDeminiaturized = "AXWindowDeminiaturized"

    // Drawer & sheet notifications
    case drawerCreated = "AXDrawerCreated"
    case sheetCreated = "AXSheetCreated"

    // Element notifications
    case uiElementDestroyed = "AXUIElementDestroyed"
    case valueChanged = "AXValueChanged"
    case titleChanged = "AXTitleChanged"
    case resized = "AXResized"
    case moved = "AXMoved"
    case created = "AXCreated"

    // Used when UI changes require the attention of assistive application.  Pass along a user info
    // dictionary with the key NSAccessibilityUIElementsKey and an array of elements that have been
    // added or changed as a result of this layout change.
    case layoutChanged = "AXLayoutChanged"

    // Misc notifications
    case helpTagCreated = "AXHelpTagCreated"
    case selectedTextChanged = "AXSelectedTextChanged"
    case rowCountChanged = "AXRowCountChanged"
    case selectedChildrenChanged = "AXSelectedChildrenChanged"
    case selectedRowsChanged = "AXSelectedRowsChanged"
    case selectedColumnsChanged = "AXSelectedColumnsChanged"
    case loadComplete = "AXLoadComplete"

    case rowExpanded = "AXRowExpanded"
    case rowCollapsed = "AXRowCollapsed"

    // Cell-table notifications
    case selectedCellsChanged = "AXSelectedCellsChanged"

    // Layout area notifications
    case unitsChanged = "AXUnitsChanged"
    case selectedChildrenMoved = "AXSelectedChildrenMoved"

    // This notification allows an application to request that an announcement be made to the user
    // by an assistive application such as VoiceOver.  The notification requires a user info
    // dictionary with the key NSAccessibilityAnnouncementKey and the announcement as a localized
    // string.  In addition, the key NSAccessibilityAnnouncementPriorityKey should also be used to
    // help an assistive application determine the importance of this announcement.  This
    // notification should be posted for the application element.
    case announcementRequested = "AXAnnouncementRequested"
}
