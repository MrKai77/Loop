//
//  Keycorder.swift
//  Loop
//
//  Created by Kai Azim on 2023-11-10.
//

import Carbon.HIToolbox
import Defaults
import Luminare
import SwiftUI

struct Keycorder: View {
    @EnvironmentObject private var model: KeybindsConfigurationModel
    @Environment(\.appearsActive) private var appearsActive

    let keyLimit: Int = 5

    @Default(.triggerKey) var triggerKey

    @Binding private var validCurrentKeybind: Set<CGKeyCode>
    @State private var selectionKeybind: Set<CGKeyCode>
    @Binding private var direction: WindowDirection
    @Binding private var bypassTriggerKey: Bool?

    @State private var eventMonitor: LocalEventMonitor?
    @State private var shouldShake: Bool = false
    @State private var shouldError: Bool = false
    @State private var errorMessage: LocalizedStringKey = .init(String("")) // We use Text here for String interpolation with images

    @State private var isHovering: Bool = false
    @State private var isActive: Bool = false

    init(_ keybind: Binding<WindowAction>) {
        self._validCurrentKeybind = keybind.keybind
        self._direction = keybind.direction
        self._bypassTriggerKey = keybind.bypassTriggerKey
        self._selectionKeybind = State(initialValue: keybind.wrappedValue.keybind)
    }

    var body: some View {
        Button {
            guard !isActive else { return }
            startObservingKeys()
        } label: {
            if selectionKeybind.isEmpty {
                Text(isActive ? "\(Image(systemName: "ellipsis"))" : "\(Image(systemName: "exclamationmark.triangle"))")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: 27, height: 27)
                    .font(.callout)
                    .luminarePlateau()
            } else {
                HStack(spacing: 4) {
                    // First show modifiers in order
                    let sortedKeys = selectionKeybind.sorted { (a: CGKeyCode, b: CGKeyCode) in
                        if a.isModifier, !b.isModifier { return true }
                        if !a.isModifier, b.isModifier { return false }
                        return a < b
                    }

                    ForEach(sortedKeys, id: \.self) { key in
                        if let systemImage = key.modifierSystemImage {
                            Text("\(Image(systemName: systemImage))")
                        } else if let humanReadable = key.humanReadable {
                            Text(humanReadable)
                        }
                    }
                    .frame(width: 27, height: 27)
                    .font(.callout)
                    .luminarePlateau(isHovering: isHovering)
                }
                .contentShape(.rect)
            }
        }
        .modifier(ShakeEffect(shakes: shouldShake ? 2 : 0))
        .animation(Animation.default, value: shouldShake)
        .popover(isPresented: $shouldError, arrowEdge: .bottom) {
            Text(errorMessage)
                .multilineTextAlignment(.center)
                .padding(8)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .onChange(of: model.currentEventMonitor) { _ in
            if model.currentEventMonitor != eventMonitor {
                finishedObservingKeys(wasForced: true)
            }
        }
        .onChange(of: appearsActive) { _ in
            if appearsActive {
                finishedObservingKeys(wasForced: true)
            }
        }
        .onChange(of: validCurrentKeybind) { _ in
            if selectionKeybind != validCurrentKeybind {
                selectionKeybind = validCurrentKeybind
            }
        }
        .buttonStyle(.plain)
        // Don't allow the button to be pressed if more than one keybind is selected in the list
        .allowsHitTesting(model.selectedKeybinds.count <= 1)
    }

    func startObservingKeys() {
        selectionKeybind = []
        isActive = true
        eventMonitor = LocalEventMonitor(events: [.keyDown, .keyUp]) { event in
            // Handle regular key presses first
            if event.type == .keyDown, !event.isARepeat {
                if event.keyCode == .kVK_Escape {
                    finishedObservingKeys(wasForced: true)
                    return nil
                }

                handleKeyDown(with: event)
            }

            if event.type == .keyUp {
                finishedObservingKeys()
                return nil
            }

            return nil
        }

        eventMonitor!.start()
        model.currentEventMonitor = eventMonitor
    }

    /// Handles key presses and updates the current keybind
    func handleKeyDown(with event: NSEvent) {
        /// Get current selected keys that aren't modifiers
        let currentKeys = selectionKeybind + [event.keyCode]
            .map { $0.baseKey(flags: event.modifierFlags) }

        var flags = CGEventFlags(cocoaFlags: event.modifierFlags)

        if event.keyCode.isFnSpecialKey {
            flags.remove(.maskSecondaryFn)
        }

        let validModifiers = if bypassTriggerKey == true {
            flags.keyCodes
        } else {
            flags.keyCodes.filter {
                !Defaults[.triggerKey]
                    .map(\.baseModifier)
                    .contains($0)
            }
        }

        let finalKeys = Set(currentKeys + validModifiers)

        shouldError = false

        /// Make sure we don't go over the key limit
        guard finalKeys.count <= keyLimit else {
            errorMessage = "You can only use up to \(keyLimit) keys in a keybind, including the trigger key."
            shouldShake.toggle()
            shouldError = true
            return
        }

        if bypassTriggerKey == true {
            let systemKeybinds = CGKeyCode.systemKeybinds
            if systemKeybinds.contains(finalKeys) {
                errorMessage = "This shortcut is used by macOS and may not work as expected."
                shouldShake.toggle()
                shouldError = true
            }
        }

        selectionKeybind = finalKeys
    }

    func finishedObservingKeys(wasForced: Bool = false) {
        isActive = false
        var willSet = !wasForced

        if validCurrentKeybind == selectionKeybind {
            willSet = false
        }

        if willSet {
            // Validate keybind requirements when in bypass mode
            if bypassTriggerKey == true {
                let normalizedKeys = selectionKeybind.map(\.baseModifier)
                let modifierKeys = normalizedKeys.filter { $0.isModifier }
                let nonModifierKeys = normalizedKeys.filter { !$0.isModifier }

                // Check: at least one modifier key
                if modifierKeys.isEmpty {
                    errorMessage = "You must include at least one modifier key (⌘, ⌃, ⌥, ⇧, or \(Image(systemName: "globe")))."
                    shouldShake.toggle()
                    shouldError = true
                    willSet = false
                }
                // Check: at least one non-modifier key
                else if nonModifierKeys.isEmpty {
                    errorMessage = "You must include at least one non-modifier key."
                    shouldShake.toggle()
                    shouldError = true
                    willSet = false
                }
                // Check: maximum of 5 keys total
                else if selectionKeybind.count > 5 {
                    errorMessage = "You can use a maximum of 5 keys in a custom shortcut."
                    shouldShake.toggle()
                    shouldError = true
                    willSet = false
                }
            }

            let effectiveSelection = bypassTriggerKey == true
                ? selectionKeybind
                : triggerKey.union(selectionKeybind)

            for keybind in Defaults[.keybinds] {
                let effectiveExisting = keybind.bypassTriggerKey == true
                    ? keybind.keybind
                    : triggerKey.union(keybind.keybind)

                guard effectiveSelection == effectiveExisting else { continue }

                willSet = false

                if let name = keybind.name, !name.isEmpty {
                    errorMessage = "That keybind is already being used by \(name)."
                } else if keybind.direction == .custom {
                    errorMessage = "That keybind is already being used by another custom keybind."
                } else if keybind.direction == .stash {
                    errorMessage = "That keybind is already being used by another stash keybind."
                } else {
                    errorMessage = "That keybind is already being used by \(keybind.direction.name.lowercased())."
                }

                shouldShake.toggle()
                shouldError = true
                break
            }
        }

        if willSet {
            // Set the valid keybind to the current selected one
            validCurrentKeybind = selectionKeybind
        } else {
            // Set preview keybind back to previous one
            selectionKeybind = validCurrentKeybind
        }

        eventMonitor?.stop()
        eventMonitor = nil
    }
}
