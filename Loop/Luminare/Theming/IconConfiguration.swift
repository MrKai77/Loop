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
    @Published var selectedLockedMessage: LocalizedStringKey = .init("")
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
        guard let window = LuminareManager.luminare else { return }
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
                            title: Text("Icon Locked"),
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
                VStack(alignment: .center) {
                    Spacer()
                    Image(._18PxLock)
                        .foregroundStyle(.secondary)

                    Text(nextUnlockCount == icon.unlockTime ?
                        .init(localized: "Loops left to unlock a new icon", defaultValue: "\(loopsLeft) Loops left") :
                        .init(localized: "Locked", comment: "When an app icon is locked")
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .contentTransition(.numericText())

                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    model.selectedLockedMessage = model.lockedMessages.randomElement() ?? ""
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
            withAnimation(.smooth(duration: 0.25)) {
                hasBeenUnlocked = icon.selectable
            }

            if !hasBeenUnlocked {
                withAnimation(.smooth(duration: 0.25)) {
                    nextUnlockCount = model.nextIconUnlockLoopCount(timesLooped: timesLooped)
                    loopsLeft = nextUnlockCount - timesLooped
                }
            }
        }
    }
}
