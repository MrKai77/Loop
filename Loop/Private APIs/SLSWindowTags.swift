//
//  SLSWindowTags.swift
//  Loop
//
//  Created by Kai Azim on 2026-04-29.
//

import Foundation

/// Tags returned by `SLSWindowIteratorGetTags`.
///
/// Bit positions and names are sourced from SkyLight's internal short-name debug table
/// at `__cstring 0x1871fa9a2+` on 26.3.1 (25D771280a), which is the main bit-position-ordered list
/// the binary itself uses. Older NUIKit headers (https://github.com/NUIKit/CGSInternal)
/// were also used as reference, however it describes a partly-stale layout, and the current
/// SkyLight has inserted/renamed several Hi bits since NUIKit was last updated.
struct SLSWindowTags: OptionSet {
    let rawValue: UInt64

    // MARK: - Lo bits (UInt64 bits 0...31)

    /// The window appears in the default style of macOS windows. "Document" is most likely a historical name.
    static let document = Self(rawValue: 1 << 0)

    /// The window appears floating over other windows. Often combined with non-activating
    /// bits to enable floating panels.
    static let floating = Self(rawValue: 1 << 1)

    /// Disables the window's badging when it is minimized into its Dock Tile.
    static let doNotShowBadgeInDock = Self(rawValue: 1 << 2)

    /// The window is displayed without a shadow, ignoring any given shadow parameters.
    static let disableShadow = Self(rawValue: 1 << 3)

    /// The WindowServer resamples the window at a higher rate. Can hurt performance.
    static let highQualityResampling = Self(rawValue: 1 << 4)

    /// The window may set the cursor when its application is not active. Useful for
    /// windows that present controls like editable text fields.
    static let setsCursorInBackground = Self(rawValue: 1 << 5)

    /// The window continues to operate while a modal run loop has been pushed.
    static let worksWhenModal = Self(rawValue: 1 << 6)

    /// The window is anchored to another window.
    static let attached = Self(rawValue: 1 << 7)

    /// When dragging, the window will ignore any alpha and appear 100% opaque.
    static let ignoreAlphaForDragging = Self(rawValue: 1 << 8)

    /// The window appears transparent to events. Mouse events pass through it to the next
    /// eligible responder. This bit or `opaqueForEvents` must be exclusively set.
    static let ignoreForEvents = Self(rawValue: 1 << 9)

    /// The window appears opaque to events. Mouse events are intercepted by the window when
    /// necessary. This bit or `ignoreForEvents` must be exclusively set.
    static let opaqueForEvents = Self(rawValue: 1 << 10)

    /// The window appears on all workspaces regardless of where it was created. Used for QuickLook panels.
    static let onAllWorkspaces = Self(rawValue: 1 << 11)

    /// Pointer events for this window bypass the standard CPS (Connection Process Service)
    /// dispatch path. Used by system overlays that handle their own pointer routing.
    static let pointerEventsAvoidCPS = Self(rawValue: 1 << 12)

    /// Tracks AppKit's view of whether the window is visible.
    static let kitVisible = Self(rawValue: 1 << 13)

    /// On application deactivation the window disappears from the window list.
    static let hideOnDeactivate = Self(rawValue: 1 << 14)

    /// When the window appears it will not bring the application to the forefront.
    static let avoidsActivation = Self(rawValue: 1 << 15)

    /// When the window is selected it will not bring the application to the forefront.
    static let preventsActivation = Self(rawValue: 1 << 16)

    /// Set on system UI windows (Dock and one other system app) to opt them out of
    /// Option-modifier-driven activation behavior (e.g. Hide Others). (this is a guess)
    static let ignoresOption = Self(rawValue: 1 << 17)

    /// The window ignores the window cycling mechanism.
    static let ignoresCycle = Self(rawValue: 1 << 18)

    /// The window defers ordering operations.
    static let defersOrdering = Self(rawValue: 1 << 19)

    /// The window defers activation.
    static let defersActivation = Self(rawValue: 1 << 20)

    /// WindowServer ignores all requests to order this window front (e.g. via `_SLSSetFrontWindow`).
    static let ignoreAsFrontWindow = Self(rawValue: 1 << 21)

    /// The WindowServer handles window dragging itself, so the window stays movable even if its application stalls.
    static let enableServerSideDrag = Self(rawValue: 1 << 22)

    /// Mouse-down events on the window are grabbed (intercepted) rather than dispatched normally.
    static let mouseDownEventsGrabbed = Self(rawValue: 1 << 23)

    /// The window ignores all requests to hide.
    static let dontHide = Self(rawValue: 1 << 24)

    /// The display containing the window is not dimmed.
    static let dontDimWindowDisplay = Self(rawValue: 1 << 25)

    /// The window converts all pointers (mice, tablet pens, etc.) to its preferred pointer type when they enter it.
    static let instantMouserWindow = Self(rawValue: 1 << 26)

    /// The window appears only on active spaces and follows the user across space changes.
    static let ownerFollowsForeground = Self(rawValue: 1 << 27)

    /// The window has separate active and inactive levels (managed via the
    /// `kCGSActiveWindowLevel` / `kCGSInactiveWindowLevel` properties).
    static let activationWindowLevel = Self(rawValue: 1 << 28)

    /// The window brings its owning application to the forefront when selected.
    static let bringOwnerForward = Self(rawValue: 1 << 29)

    /// The window is allowed to appear over the login screen.
    static let permittedBeforeLogin = Self(rawValue: 1 << 30)

    /// The window is modal.
    static let modal = Self(rawValue: 1 << 31)

    // MARK: - Hi bits (UInt64 bits 32...63)

    /// Likely relates to the system's built-in window management (Stage Manager and the built-in WM);
    /// probably marks windows whose owning app cooperates with those features?
    static let windowManagerAware = Self(rawValue: 1 << 32)

    /// The window follows the user across the currently-focused document space. Disqualified
    /// by `ignoresWorkspaceHeuristics` or by being `attached`.
    static let followsDocumentSpace = Self(rawValue: 1 << 33)

    /// The window is excluded from mirror reflections (mirrored displays, magic-mirror surfaces).
    static let noMirrorReflection = Self(rawValue: 1 << 34)

    /// Internal compositor flag. Exact meaning currently unclear :(
    static let meshed = Self(rawValue: 1 << 35)

    /// Set when CoreDrag has dragged something to the window.
    static let coreDragIsDragging = Self(rawValue: 1 << 36)

    /// The window is excluded from screen-capture streams.
    static let avoidsCapture = Self(rawValue: 1 << 37)

    /// The window is ignored for Exposé and does not change appearance when activated.
    static let ignoreForExpose = Self(rawValue: 1 << 38)

    /// The window is hidden.
    static let hidden = Self(rawValue: 1 << 39)

    /// The window is explicitly included in the window cycling mechanism.
    static let includeInCycle = Self(rawValue: 1 << 40)

    /// The window captures gesture events even when its application is not in the foreground.
    static let wantsGesturesInBackground = Self(rawValue: 1 << 41)

    /// The window is fullscreen.
    static let fullScreen = Self(rawValue: 1 << 42)

    /// The window is the magic-zoom (accessibility zoom) source. Companion to
    /// `_SLSSetMagicZoom`/`_SLSGetMagicZoomWindowID`.
    static let magicZoom = Self(rawValue: 1 << 43)

    /// A stronger variant of `onAllWorkspaces`: the window stays on every space and resists any
    /// space transitions that would normally remove it.
    static let superSticky = Self(rawValue: 1 << 44)

    /// The window is allowed to appear over fullscreen apps. Set on windows such as menu bar items.
    static let friendOfFullscreen = Self(rawValue: 1 << 45)

    /// The window is attached to the menu bar. Used for `NSMenu`s presented by menu-bar
    /// apps. Previously known as `kCGSAttachesToMenuBarTagBit` in older NUIKit headers.
    static let menuBar = Self(rawValue: 1 << 46)

    /// The window has affinity for the desktop level (a softer form of `desktopPicture`).
    static let desktopAffinity = Self(rawValue: 1 << 47)

    /// The window is forced to be space-bound. Never participates in stickiness, even if
    /// other flags would suggest otherwise. Opposite of `onAllWorkspaces` / `superSticky`.
    static let neverSticky = Self(rawValue: 1 << 48)

    /// The window appears at the level of the desktop picture.
    static let desktopPicture = Self(rawValue: 1 << 49)

    /// Opts the window out of WindowServer's workspace placement heuristics. Negates `followsDocumentSpace`.
    static let ignoresWorkspaceHeuristics = Self(rawValue: 1 << 50)

    /// When the window is redrawn it moves forward. Useful for debugging, annoying in practice.
    static let ordersForwardOnFlush = Self(rawValue: 1 << 51)

    /// The window is a user-input accessory, such as an IME panel.
    static let userInputAccessory = Self(rawValue: 1 << 52)

    /// The window does not use the standard compositing backing store.
    static let nonCompositingBackingStore = Self(rawValue: 1 << 53)

    /// When this window moves, it drags its movement-group parent along with it.
    static let dragsMovementGroupParent = Self(rawValue: 1 << 54)

    /// Layered surfaces are kept separate during swipe gestures (e.g. Mission Control swipes)
    /// instead of being flattened into a single composited image.
    static let neverFlattenSurfacesDuringSwipes = Self(rawValue: 1 << 55)

    /// The window is eligible to enter native fullscreen mode.
    static let fullScreenCapable = Self(rawValue: 1 << 56)

    /// The window is eligible to be tiled in Split View / fullscreen tile spaces.
    static let fullScreenTileCapable = Self(rawValue: 1 << 57)

    /// The window is excluded from screen sharing.
    static let ignoreForScreenSharing = Self(rawValue: 1 << 58)

    /// When the parent window is shared via screen-share or capture, this child window is shared alongside it.
    static let shareAlongWithParent = Self(rawValue: 1 << 59)

    /// The window is currently miniaturized.
    static let miniaturized = Self(rawValue: 1 << 60)

    /// The window has an indicator for shared windows?
    static let windowSharingIndicator = Self(rawValue: 1 << 61)

    /// Transient ordering changes for this window are ignored when filtering windows.
    static let ignoreTransientOrderingForFiltering = Self(rawValue: 1 << 62)

    /// The window has a trivial (single-layer) layer tree. Hint for the compositor.
    static let trivialLayerTree = Self(rawValue: 1 << 63)
}
