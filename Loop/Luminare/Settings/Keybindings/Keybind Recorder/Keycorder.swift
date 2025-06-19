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

    let keyLimit: Int = 6

    @Default(.triggerKey) var triggerKey

    @Binding private var validCurrentKeybind: Set<CGKeyCode>
    @State private var selectionKeybind: Set<CGKeyCode>
    @Binding private var direction: WindowDirection

    @State private var eventMonitor: NSEventMonitor?
    @State private var shouldShake: Bool = false
    @State private var shouldError: Bool = false
    @State private var errorMessage: LocalizedStringKey = .init(String("")) // We use Text here for String interpolation with images

    @State private var isHovering: Bool = false
    @State private var isActive: Bool = false

    init(_ keybind: Binding<WindowAction>) {
        self._validCurrentKeybind = keybind.keybind
        self._direction = keybind.direction
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
                    .modifier(LuminareBordered())
            } else {
                HStack(spacing: 5) {
                    // First show modifiers in order
                    let sortedKeys = selectionKeybind.sorted { (a: CGKeyCode, b: CGKeyCode) in
                        if a.isModifier, !b.isModifier { return true }
                        if !a.isModifier, b.isModifier { return false }
                        return a < b
                    }

                    ForEach(sortedKeys, id: \.self) { key in
                        if let systemImage = key.systemImage {
                            Text("\(Image(systemName: systemImage))")
                        } else if let humanReadable = key.humanReadable {
                            Text(humanReadable)
                        }
                    }
                    .frame(width: 27, height: 27)
                    .font(.callout)
                    .modifier(LuminareBordered(highlight: $isHovering))
                }
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
        eventMonitor = NSEventMonitor(scope: .local, eventMask: [.keyDown, .keyUp]) { event in
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
            .filter { !$0.isModifier }
            .map(\.baseKey)

        /// Get current modifiers that are actually pressed
        let modifierMapping: [(NSEvent.ModifierFlags, CGKeyCode)] = [
            (.command, .kVK_Command),
            (.option, .kVK_Option),
            (.control, .kVK_Control),
            (.shift, .kVK_Shift),
            (.function, .kVK_Function)
        ]

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let currentModifiers = Set(
            modifierMapping
                .filter { flags.contains($0.0) && $0.1.isPressed }
                .map(\.1)
        )

        // Filter out trigger keys
        let validModifiers = currentModifiers.filter {
            !Defaults[.triggerKey]
                .map(\.baseModifier)
                .contains($0)
        }

        let finalKeys = Set(currentKeys + validModifiers)

        /// Make sure we don't go over the key limit
        guard finalKeys.count < keyLimit else {
            errorMessage = "You can only use up to \(keyLimit) keys in a keybind, including the trigger key."
            shouldShake.toggle()
            shouldError = true
            return
        }

        shouldError = false
        selectionKeybind = finalKeys
    }

    func finishedObservingKeys(wasForced: Bool = false) {
        isActive = false
        var willSet = !wasForced

        if validCurrentKeybind == selectionKeybind {
            willSet = false
        }

        if willSet {
            for keybind in Defaults[.keybinds] where
                keybind.keybind == selectionKeybind {
                willSet = false

                if let name = keybind.name, !name.isEmpty {
                    self.errorMessage = "That keybind is already being used by \(name)."
                } else if keybind.direction == .custom {
                    self.errorMessage = "That keybind is already being used by another custom keybind."
                } else if keybind.direction == .stash {
                    self.errorMessage = "That keybind is already being used by another stash keybind."
                } else {
                    self.errorMessage = "That keybind is already being used by \(keybind.direction.name.lowercased())."
                }

                self.shouldShake.toggle()
                self.shouldError = true
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
