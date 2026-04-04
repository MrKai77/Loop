//
//  LoopDockTilePlugin.swift
//  LoopDockTile
//
//  Created by Kai Azim on 2026-04-03.
//

import AppKit
import Scribe

@Loggable
final class LoopDockTilePlugin: NSObject, NSDockTilePlugIn {
    private var dockTile: NSDockTile?
    private var notificationObserver: Any?
    private let appBundleID = "com.MrKai77.Loop"
    private let notificationName = Notification.Name("com.MrKai77.Loop.iconChanged")
    private lazy var appDefaults = UserDefaults(suiteName: appBundleID)

    /// The host app bundle, resolved from the plugin's location inside Contents/PlugIns/
    private lazy var hostAppBundle: Bundle? = {
        let pluginBundle = Bundle(for: type(of: self))
        let plugInsURL = pluginBundle.bundleURL.deletingLastPathComponent()
        let contentsURL = plugInsURL.deletingLastPathComponent()
        let appURL = contentsURL.deletingLastPathComponent()
        return Bundle(url: appURL)
    }()

    func setDockTile(_ dockTile: NSDockTile?) {
        self.dockTile = dockTile

        notificationObserver = DistributedNotificationCenter.default().addObserver(
            forName: notificationName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let iconName = notification.userInfo?["iconName"] as? String
            let isDefault = notification.userInfo?["isDefault"] as? Bool
            self?.updateDockTile(iconName: iconName, isDefault: isDefault)
        }

        // On initial load, we don't have notification userInfo, so read from preferences
        updateDockTile(iconName: nil, isDefault: nil)
    }

    private func updateDockTile(iconName: String?, isDefault: Bool?) {
        guard let dockTile else { return }

        // Fall back to reading preferences if values aren't sent through notification
        let resolvedIsDefault: Bool
        if let isDefault {
            resolvedIsDefault = isDefault
        } else {
            let storedIcon = appDefaults?.string(forKey: "currentIcon")
            let bundleAppIcon = hostAppBundle?.infoDictionary?["CFBundleIconName"] as? String
            resolvedIsDefault = storedIcon == nil || storedIcon == bundleAppIcon
        }

        if resolvedIsDefault {
            dockTile.contentView = nil
            log.info("Cleared dock tile content view")
        } else if let iconName = iconName ?? appDefaults?.string(forKey: "currentIcon"),
                  let image = hostAppBundle?.image(forResource: iconName) {
            let imageView = NSImageView(image: image)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.wantsLayer = true
            dockTile.contentView = imageView
            log.info("Set image as dock tile content view")
        } else {
            log.error("Failed to load icon image")
        }

        dockTile.display()
    }

    deinit {
        if let observer = notificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
}
