//
//  IconConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import SwiftUI
import Luminare
import Defaults

struct IconConfigurationView: View {
    @Default(.currentIcon) var currentIcon
    @Default(.showDockIcon) var showDockIcon
    @Default(.notificationWhenIconUnlocked) var notificationWhenIconUnlocked

    var body: some View {
        LuminareSection(showDividers: false) {
            LuminarePicker(
                elements: IconManager.icons,
                selection: Binding(
                    get: {
                        IconManager.currentAppIcon
                    },
                    set: { newValue in
                        currentIcon = newValue.iconName
                        IconManager.refreshCurrentAppIcon()
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
                print("TODO: SUGGEST NEW ICON")
            }
        }

        LuminareSection("Options") {
            LuminareToggle("Show in dock", isOn: $showDockIcon)
            LuminareToggle(
                "Notify when unlocking new icons ",
                isOn: Binding(
                    get: {
                        self.notificationWhenIconUnlocked
                    },
                    set: {
                        if $0 {
                            let notficationBody: String = .init(
                                localized: .init(
                                    "Default notification content",
                                    defaultValue: "You will now be notified when you unlock a new icon."
                                )
                            )
                            AppDelegate.sendNotification(Bundle.main.appName, notficationBody)

                            let areNotificationsEnabled = AppDelegate.areNotificationsEnabled()
                            self.notificationWhenIconUnlocked = areNotificationsEnabled

    //                        if !areNotificationsEnabled {
    //                            self.userDisabledLoopNotifications = true
    //                        }
                        } else {
                            self.notificationWhenIconUnlocked = $0
                        }
                    }
                )
            )
        }
    }
}
