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

    @Published var showingLockedAlert = false
    @Published var selectedLockedMessage: String = ""
    let lockedMessages: [String] = [
        .init(localized: "Locked icon message 1", defaultValue: "You don’t have that yet!"),
        .init(localized: "Locked icon message 2", defaultValue: "Who do you think you are, trying to access these top secret icons?"),
        .init(localized: "Locked icon message 3", defaultValue: "Patience is a virtue, and your key to this icon."),
        .init(localized: "Locked icon message 4", defaultValue: "This icon is locked, but your potential is not!"),
        .init(localized: "Locked icon message 5", defaultValue: "Keep Looping, and this icon will be yours in no time."),
        .init(localized: "Locked icon message 6", defaultValue: "This icon is still under wraps, stay tuned!"),
        .init(localized: "Locked icon message 7", defaultValue: "Some icons are worth the wait, don't you think?"),
        .init(localized: "Locked icon message 8", defaultValue: "Not yet, but you're closer than you were yesterday!"),
        .init(localized: "Locked icon message 9", defaultValue: "Unlocking this icon is just a matter of time and Loops."),
        .init(localized: "Locked icon message 10", defaultValue: "This icon is like a fine wine, it needs more time."),
        .init(localized: "Locked icon message 11", defaultValue: "Stay curious, and soon this icon will be within your reach."),
        .init(localized: "Locked icon message 12", defaultValue: "Keep up the good work, and this icon will be your reward."),
        .init(localized: "Locked icon message 13", defaultValue: "This icon is reserved for the most dedicated Loopers."),
        .init(localized: "Locked icon message 14", defaultValue: "Your journey is not yet complete, this icon awaits at the end."),
        .init(localized: "Locked icon message 15", defaultValue: "In due time, this icon shall be revealed to you."),
        .init(localized: "Locked icon message 16", defaultValue: "Patience, young Looper, this icon is not far away."),
        .init(localized: "Locked icon message 17", defaultValue: "The journey of a thousand Loops begins with a single step."),
        .init(localized: "Locked icon message 18", defaultValue: "Every Loop brings you closer to the treasure that awaits."),
        .init(localized: "Locked icon message 19", defaultValue: "With each Loop, the lock on this icon weakens."),
        .init(localized: "Locked icon message 20", defaultValue: "Loop after Loop, your dedication carves the key to success."),
        .init(localized: "Locked icon message 21", defaultValue: "The icons are not just unlocked; they're earned, Loop by Loop."),
        .init(localized: "Locked icon message 22", defaultValue: "As the Loops accumulate, so too will your collection of icons."),
        .init(localized: "Locked icon message 23", defaultValue: "Think of each Loop as a riddle, solving the mystery of the locked icon."),
        .init(localized: "Locked icon message 24", defaultValue: "Your persistence in Looping is the master key to all icons."),
        .init(localized: "Locked icon message 25", defaultValue: "Loop around the obstacles; your reward is just beyond them."),
        .init(localized: "Locked icon message 26", defaultValue: "Each Loop you complete plants the seeds for icons to grow."),
        .init(localized: "Locked icon message 27", defaultValue: "Like the moon's phases, your icons will reveal themselves in cycles of Loops."),
        .init(localized: "Locked icon message 28", defaultValue: "The icons await, hidden behind the veil of Loops yet to be made.")
    ]
    private var shuffledTexts: [String] = []

    func getNextUpToDateText() -> String {
        // If shuffledTexts is empty, fill it with a shuffled version of lockedMessages
        if shuffledTexts.isEmpty {
            shuffledTexts = lockedMessages.filter { $0 != "-" }.shuffled()
        }
        // Pop the last element to ensure it's not repeated until all have been shown
        return shuffledTexts.popLast() ?? lockedMessages[0] // Fallback string
    }

    private func handleNotificationChange() {
        if notificationWhenIconUnlocked {
            AppDelegate.sendNotification(
                Bundle.main.appName,
                .init(localized: "Icon notifications enabled", defaultValue: "You will now be notified when you unlock a new icon.")
            )
            if !AppDelegate.areNotificationsEnabled() {
                notificationWhenIconUnlocked = false
                userDisabledNotificationsAlert()
            }
        }
    }

    private func userDisabledNotificationsAlert() {
        guard let window = LuminareManager.luminare else { return }
        let alert = NSAlert()
        alert.messageText = .init(localized: "Notification permits: info", defaultValue: "\(Bundle.main.appName)'s notification permissions are currently disabled.")
        alert.informativeText = .init(localized: "Notification permits: request", defaultValue: "Please turn them on in System Settings.")
        alert.addButton(withTitle: .init(localized: "Notification permits: open notification settings", defaultValue: "Open Settings"))
        alert.alertStyle = .warning

        alert.beginSheetModal(for: window) { modalResponse in
            if modalResponse == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
            }
        }
    }

    func nextIconUnlockLoopCount(timesLooped: Int) -> Int {
        Icon.all.first { $0.unlockTime > timesLooped }?.unlockTime ?? 0
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
                    get: { IconManager.currentAppIcon },
                    set: { model.currentIcon = $0.iconName }
                ),
                roundBottom: false
            ) { icon in
                IconVew(model: model, icon: icon)
                    .aspectRatio(1, contentMode: .fit)
                    .alert(isPresented: $model.showingLockedAlert) {
                        Alert(
                            title: Text(.init(localized: "Locked icon alert title", defaultValue: "Icon Locked")),
                            message: Text(model.selectedLockedMessage),
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

struct IconVew: View {
    @ObservedObject var model: IconConfigurationModel
    let icon: Icon

    @State private var hasBeenUnlocked: Bool = false
    @Default(.timesLooped) var timesLooped
    @State private var nextUnlockCount: Int = -1
    @State private var loopsLeft: Int = -1

    var body: some View {
        ZStack {
            if hasBeenUnlocked {
                Image(nsImage: NSImage(named: icon.iconName)!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(10)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else {
                HStack {
                    Spacer()
                    VStack(alignment: .center) {
                        Spacer()
                        Image(._18PxLock)
                            .foregroundStyle(.secondary)

                        Text(nextUnlockCount == icon.unlockTime ?
                            .init(localized: "Loops left to unlock new icon", defaultValue: "\(loopsLeft) Loops left") :
                            .init(localized: "App icon is locked", defaultValue: "Locked")
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .contentTransition(.numericText())

                        Spacer()
                    }
                    Spacer()
                }
                .onTapGesture {
                    model.selectedLockedMessage = model.getNextUpToDateText()
                    model.showingLockedAlert = true
                }
            }
        }
        .onAppear {
            hasBeenUnlocked = icon.selectable

            if !hasBeenUnlocked {
                nextUnlockCount = model.nextIconUnlockLoopCount(timesLooped: timesLooped)
                loopsLeft = nextUnlockCount - timesLooped
            }
        }
        .onChange(of: timesLooped) { _ in
            withAnimation(LuminareConstants.animation) {
                hasBeenUnlocked = icon.selectable
            }

            if !hasBeenUnlocked {
                withAnimation(LuminareConstants.animation) {
                    nextUnlockCount = model.nextIconUnlockLoopCount(timesLooped: timesLooped)
                    loopsLeft = nextUnlockCount - timesLooped
                }
            }
        }
    }
}
