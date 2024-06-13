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
    @EnvironmentObject private var model: KeybindingsConfigurationModel

    let keyLimit: Int = 6

    @Default(.triggerKey) var triggerKey

    @Binding private var validCurrentKeybind: Set<CGKeyCode>
    @State private var selectionKeybind: Set<CGKeyCode>
    @Binding private var direction: WindowDirection

    @State private var eventMonitor: NSEventMonitor?
    @State private var shouldShake: Bool = false
    @State private var shouldError: Bool = false
    @State private var errorMessage: Text = .init("") // We use Text here for String interpolation with images

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
                    ForEach(selectionKeybind.sorted(), id: \.self) { key in
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
            errorMessage
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
        .onChange(of: validCurrentKeybind) { _ in
            if selectionKeybind != validCurrentKeybind {
                selectionKeybind = validCurrentKeybind
            }
        }
        .onReceive(.activeStateChanged) { notif in
            if let active = notif.object as? Bool, active == false {
                finishedObservingKeys(wasForced: true)
            }
        }
        .buttonStyle(PlainButtonStyle())

        // Don't allow the button to be pressed if more than one keybind is selected in the list
        .allowsHitTesting(model.selectedKeybinds.count <= 1)
    }

    func startObservingKeys() {
        selectionKeybind = []
        isActive = true
        eventMonitor = NSEventMonitor(scope: .local, eventMask: [.keyDown, .keyUp, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                if !Defaults[.triggerKey].contains(where: { $0.baseModifier == event.keyCode.baseModifier }) {
                    shouldError = false
                    selectionKeybind.insert(event.keyCode.baseModifier)
                } else {
                    if let systemImage = event.keyCode.baseModifier.systemImage {
                        errorMessage = Text("\(Image(systemName: systemImage)) is already used as your trigger key.")
                    } else {
                        errorMessage = Text("That key is already used as your trigger key.")
                    }

                    shouldShake.toggle()
                    shouldError = true
                }
            }

            if event.type == .keyUp ||
                (event.type == .flagsChanged && !selectionKeybind.isEmpty && event.modifierFlags.rawValue == 256) {
                finishedObservingKeys()
                return
            }

            if event.type == .keyDown, !event.isARepeat {
                if event.keyCode == CGKeyCode.kVK_Escape {
                    finishedObservingKeys(wasForced: true)
                    return
                }

                if (selectionKeybind.count + triggerKey.count) >= keyLimit {
                    errorMessage = Text(
                        "You can only use up to \(keyLimit) keys in a keybind, including the trigger key."
                    )
                    shouldShake.toggle()
                    shouldError = true
                } else {
                    shouldError = false
                    selectionKeybind.insert(event.keyCode)
                }
            }
        }

        eventMonitor!.start()
        model.currentEventMonitor = eventMonitor
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
                if keybind.direction == .custom {
                    if let name = keybind.name {
                        self.errorMessage = Text("That keybind is already being used by \(name).")
                    } else {
                        self.errorMessage = Text("That keybind is already being used by another custom keybind.")
                    }
                } else {
                    self.errorMessage = Text(
                        "That keybind is already being used by \(keybind.direction.name.lowercased())."
                    )
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
