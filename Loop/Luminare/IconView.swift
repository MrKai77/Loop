//
//  IconView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-19.
//

import SwiftUI
import Luminare
import Defaults

struct IconView: View {
    @Default(.currentIcon) var currentIcon
    @Default(.showDockIcon) var showDockIcon
    @Default(.notificationWhenIconUnlocked) var notificationWhenIconUnlocked

    @State var icon: IconManager.Icon = IconManager.currentAppIcon {
        didSet {
            self.currentIcon = icon.iconName
        }
    }

    var body: some View {
        LuminareSection(showDividers: false) {
            LuminarePicker(elements: IconManager.icons, selection: $icon, roundBottom: false) { icon in
                Group {
                    if icon.selectable {
                        Image(nsImage: NSImage(named: icon.iconName)!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(5)
                    } else {
                        VStack(alignment: .center) {
                            Spacer()

                            Image(systemName: "lock")
                                .font(.title3)
                                .padding(5)

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
            LuminareToggle("Notify when unlocking new icons ", isOn: $notificationWhenIconUnlocked)
        }
    }
}
