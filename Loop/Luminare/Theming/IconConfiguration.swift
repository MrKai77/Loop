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
    static let suggestNewIconLink = URL(string: "https://github.com/MrKai77/Loop/issues/new/choose")!

    @Published var currentIcon: String = Defaults[.currentIcon] {
        didSet {
            if oldValue != currentIcon {
                Defaults[.currentIcon] = currentIcon
                IconManager.refreshCurrentAppIcon()
            }
        }
    }

    @Published var showDockIcon: Bool = Defaults[.showDockIcon] {
        didSet {
            if oldValue != showDockIcon {
                Defaults[.showDockIcon] = showDockIcon
            }
        }
    }

    @Published var notificationWhenIconUnlocked: Bool = Defaults[.notificationWhenIconUnlocked] {
        didSet {
            if oldValue != notificationWhenIconUnlocked {
                Defaults[.notificationWhenIconUnlocked] = notificationWhenIconUnlocked
                handleNotificationChange()
            }
        }
    }

    private func handleNotificationChange() {
        if notificationWhenIconUnlocked {
            AppDelegate.sendNotification(Bundle.main.appName, "You will now be notified when you unlock a new icon.")
            if !AppDelegate.areNotificationsEnabled() {
                notificationWhenIconUnlocked = false
                userDisabledNotificationsAlert()
            }
        }
    }

    private func userDisabledNotificationsAlert() {
        guard let window = LuminareManager.window else { return }
        let alert = NSAlert()
        alert.messageText = "\(Bundle.main.appName)'s notification permissions are currently disabled."
        alert.informativeText = "Please turn them on in System Settings."
        alert.addButton(withTitle: "Open Settings")
        alert.alertStyle = .warning

        alert.beginSheetModal(for: window) { modalResponse in
            if modalResponse == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
            }
        }
    }

    func nextIconUnlockLoopCount(timesLooped: Int) -> Int? {
        Icon.all.first { $0.unlockTime > timesLooped }?.unlockTime
    }
}

struct IconConfigurationView: View {
    @Environment(\.openURL) var openURL
    @StateObject private var model = IconConfigurationModel()
    @Default(.timesLooped) var timesLooped
    @State private var showingLockedAlert = false
    @State private var selectedLockedMessage = LocalizedStringKey("")

    let lockedMessages: [LocalizedStringKey] = [
        "You don’t have that yet!",
        "Who do you think you are, trying to access these top secret icons?",
        "Patience is a virtue, and your key to this icon.",
        "This icon is locked, but your potential is not!",
        "Keep looping, and this icon will be yours in no time.",
        "This icon is still under wraps, stay tuned!",
        "Some icons are worth the wait, don't you think?",
        "Not yet, but you're closer than you were yesterday!",
        "Unlocking this icon is just a matter of time and loops.",
        "This icon is like a fine wine, it needs more time.",
        "Stay curious, and soon this icon will be within your reach.",
        "Keep up the good work, and this icon will be your reward.",
        "This icon is reserved for the most dedicated loopers.",
        "Your journey is not yet complete, this icon awaits at the end.",
        "In due time, this icon shall be revealed to you.",
        "Patience, young looper, this icon is not far away.",
        "The journey of a thousand loops begins with a single step.",
        "Every loop brings you closer to the treasure that awaits.",
        "With each loop, the lock on this icon weakens.",
        "Loop after loop, your dedication carves the key to success.",
        "The icons are not just unlocked; they're earned, loop by loop.",
        "As the loops accumulate, so too will your collection of icons.",
        "Think of each loop as a riddle, solving the mystery of the locked icon.",
        "Your persistence in looping is the master key to all icons.",
        "Loop around the obstacles; your reward is just beyond them.",
        "Each loop you complete plants the seeds for icons to grow.",
        "Like the moon's phases, your icons will reveal themselves in cycles of loops.",
        "The icons await, hidden behind the veil of loops yet to be made."
    ]

    var body: some View {
        LuminareSection(showDividers: false) {
            LuminarePicker(
                elements: Icon.all,
                selection: Binding(
                    get: { IconManager.currentAppIcon },
                    set: { model.currentIcon = $0.iconName }
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
                            Image(._18PxLock)
                            if let nextUnlockCount = model.nextIconUnlockLoopCount(timesLooped: timesLooped),
                               nextUnlockCount == icon.unlockTime {
                                Text("\(nextUnlockCount - timesLooped) Loops left")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Locked")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedLockedMessage = lockedMessages.randomElement() ?? ""
                            showingLockedAlert = true
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .alert(isPresented: $showingLockedAlert) {
                    Alert(
                        title: Text("Icon Locked"),
                        message: Text(selectedLockedMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            Button("Suggest new icon") {
                openURL(IconConfigurationModel.suggestNewIconLink)
            }
        }
        LuminareSection("Options") {
            LuminareToggle("Show in dock", isOn: $model.showDockIcon)
            LuminareToggle("Notify when unlocking new icons", isOn: $model.notificationWhenIconUnlocked)
        }
    }
}
