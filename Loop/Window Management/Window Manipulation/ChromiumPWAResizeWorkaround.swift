//
//  ChromiumPWAResizeWorkaround.swift
//  Loop
//
//  Temporary workaround for https://github.com/mrkai77/Loop/issues/1131
//
//  Chromium-installed PWA shims (`{browser}.app.{id}`) can terminate during Loop’s
//  normal AX resize path:
//    NSAccessibility Request Received → NSInvalidArgumentException →
//    app_shim_controller Channel error → clean terminate.
//
//  Upstream:
//  - Public (dup): https://issues.chromium.org/issues/539984770
//  - Canonical (restricted): https://issues.chromium.org/issues/537448007
//
//  TO REMOVE when Chromium fixes this:
//  1. Delete this file.
//  2. Delete every call site that references `ChromiumPWAResizeWorkaround`
//     (WindowEngine.performResize, WindowEngine.resizeWindow,
//     Window.ResolvedProperties.init).
//

import Foundation

enum ChromiumPWAResizeWorkaround {
    /// Bundle ID bases for Chromium browsers that install macOS PWA shims as
    /// `{base}.app.{id}` (optionally `{base}.app.{profile}-{id}`).
    private static let browserBundleIDBases: [String] = [
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.canary",
        "com.google.Chrome.dev",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.nightly",
        "com.microsoft.Edge",
        "com.microsoft.Edge.Beta",
        "com.microsoft.Edge.Dev",
        "com.microsoft.Edge.Canary",
        "org.chromium.Chromium",
        "company.thebrowser.Browser"
    ]

    static func applies(to window: Window) -> Bool {
        applies(bundleIdentifier: window.nsRunningApplication?.bundleIdentifier)
    }

    /// `true` for Chromium PWA / app-mode shims only — not the browser itself.
    static func applies(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return browserBundleIDBases.contains { bundleIdentifier.hasPrefix($0 + ".app.") }
    }

    /// Focus/raise has been observed to contribute to shim termination (#1131).
    static func shouldSkipFocus(for window: Window) -> Bool {
        applies(to: window)
    }

    /// Skip reading/toggling `AXEnhancedUserInterface` for matching windows (#1131).
    static func resolvedEnhancedUserInterface(for window: Window) -> Bool {
        applies(to: window) ? false : window.enhancedUserInterface
    }

    /// Size → position → size without touching `AXEnhancedUserInterface`.
    /// The second size write is needed because shims often ignore the first until
    /// the origin has been updated.
    static func resize(_ window: Window, to targetFrame: CGRect) {
        window.setSize(targetFrame.size)
        window.setPosition(targetFrame.origin)
        window.setSize(targetFrame.size)
    }
}
