//
//  IconConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import Defaults
import Luminare
import SwiftUI

class IconConfigurationModel: ObservableObject {
    let suggestNewIconLink = URL(string: "https://github.com/MrKai77/Loop/issues/new/choose")!

    @Published var currentIcon = Defaults[.currentIcon] {
        didSet {
            Defaults[.currentIcon] = currentIcon

            DispatchQueue.main.async {
                IconManager.refreshCurrentAppIcon()
            }
        }
    }

    @Published var showDockIcon = Defaults[.showDockIcon] {
        didSet {
            Defaults[.showDockIcon] = showDockIcon
        }
    }

    @Published var notificationWhenIconUnlocked = Defaults[.notificationWhenIconUnlocked] {
        didSet {
            Defaults[.notificationWhenIconUnlocked] = notificationWhenIconUnlocked

            if notificationWhenIconUnlocked {
                let notficationBody: String = .init(
                    localized: .init(
                        "Default notification content",
                        defaultValue: "You will now be notified when you unlock a new icon."
                    )
                )
                AppDelegate.sendNotification(Bundle.main.appName, notficationBody)

                let areNotificationsEnabled = AppDelegate.areNotificationsEnabled()

                if !areNotificationsEnabled {
                    notificationWhenIconUnlocked = false
                    userDisabledNotificationsAlert()
                }
            }
        }
    }

    private func userDisabledNotificationsAlert() {
        guard
            let window = LuminareManager.window
        else {
            return
        }
        let alert = NSAlert()
        alert.messageText = "\(Bundle.main.appName)'s notification permissions are currently disabled."
        alert.informativeText = "Please turn them on in System Settings."
        alert.addButton(withTitle: "Open Settings")
        alert.alertStyle = .warning

        alert.beginSheetModal(for: window) { modalResponse in
            if modalResponse == .alertFirstButtonReturn {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
                )
            }
        }
    }
}

struct IconConfigurationView: View {
    @Environment(\.openURL) var openURL
    @StateObject private var model = IconConfigurationModel()

    var body: some View {
        LuminareSection(showDividers: false) {
            LuminarePicker(
                elements: Icon.all,
                selection: Binding(
                    get: {
                        IconManager.currentAppIcon
                    },
                    set: {
                        model.currentIcon = $0.iconName
                    }
                ),
                roundBottom: false
            ) { icon in
                Group {
                    if icon.selectable {
                        Image(nsImage: NSImage(named: icon.iconName)!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(10)
                    } else {
                        VStack(alignment: .center) {
                            Spacer()

                            Image(systemName: "lock")
                                .font(.title3)

                            Spacer()
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
            }

            Button("Suggest new icon") {
                openURL(model.suggestNewIconLink)
            }
        }

        LuminareSection("Options") {
            LuminareToggle("Show in dock", isOn: $model.showDockIcon)
            LuminareToggle("Notify when unlocking new icons", isOn: $model.notificationWhenIconUnlocked)
        }
    }
}
