//
//  LogCategory+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-10.
//

import Foundation
import Scribe

/// Centralized Scribe categories used across Loop.
extension LogCategory {
    // App lifecycle & core coordination
    static let appDelegate = LogCategory("AppDelegate")
    static let loopManager = LogCategory("LoopManager")
    static let dataPatcher = LogCategory("DataPatcher")
    static let urlHandler = LogCategory("URLHandler")

    // Settings & configuration surfaces
    static let settingsWindowManager = LogCategory("SettingsWindowManager")
    static let behaviorConfigurationView = LogCategory("BehaviorConfigurationView")
    static let advancedConfigurationModel = LogCategory("AdvancedConfigurationModel")
    static let pickerView = LogCategory("PickerView")

    // Appearance & theming
    static let accentColorController = LogCategory("AccentColorController")
    static let wallpaperProcessor = LogCategory("WallpaperProcessor")
    static let iconManager = LogCategory("IconManager")

    // Window management
    static let windowUtility = LogCategory("WindowUtility")
    static let window = LogCategory("Window")
    static let windowEngine = LogCategory("WindowEngine")
    static let windowRecords = LogCategory("WindowRecords")
    static let windowAction = LogCategory("WindowAction")
    static let windowActionCache = LogCategory("WindowActionCache")
    static let windowDragManager = LogCategory("WindowDragManager")

    // Window action indicators
    static let radialMenuController = LogCategory("RadialMenuController")
    static let previewController = LogCategory("PreviewController")

    // Stashing
    static let stashManager = LogCategory("StashManager")
    static let stashedWindowsStore = LogCategory("StashedWindowsStore")
    static let stashedWindow = LogCategory("StashedWindow")

    // Event monitoring & input
    static let localEventMonitor = LogCategory("LocalEventMonitor")
    static let baseEventTapMonitor = LogCategory("BaseEventTapMonitor")
    static let passiveEventMonitor = LogCategory("PassiveEventMonitor")
    static let activeEventMonitor = LogCategory("ActiveEventMonitor")
    static let mouseInteractionObserver = LogCategory("MouseInteractionObserver")

    // Updates & maintenance
    static let updater = LogCategory("Updater")
    static let migrator = LogCategory("Migrator")

    // Private APIs
    static let skyLightToolBelt = LogCategory("SkyLightToolBelt")
    static let skyLightSymbolLoader = LogCategory("SkyLightSymbolLoader")
}
