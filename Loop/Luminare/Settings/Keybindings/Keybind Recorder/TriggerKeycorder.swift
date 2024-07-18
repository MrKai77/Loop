//
//  TriggerKeycorder.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-11.
//

import Defaults
import Luminare
import SwiftUI

struct TriggerKeycorder: View {
    @EnvironmentObject private var model: KeybindingsConfigurationModel

    let keyLimit: Int = 5

    @Binding private var validCurrentKey: Set<CGKeyCode>
    @State private var selectionKey: Set<CGKeyCode>

    @State private var eventMonitor: NSEventMonitor?
    @State private var shouldShake: Bool = false
    @State private var isHovering: Bool = false
    @State private var isActive: Bool = false
    @State private var tooManyKeysPopup: Bool = false

    init(_ key: Binding<Set<CGKeyCode>>) {
        self._validCurrentKey = key
        _selectionKey = State(initialValue: key.wrappedValue)
    }

    var body: some View {
        HStack {
            Button {
                guard !isActive else { return }
                startObservingKeys()
            } label: {
                if selectionKey.isEmpty {
                    Text(isActive ? "Set a trigger key…" : "None")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .fixedSize(horizontal: true, vertical: false)
                } else {
                    HStack(spacing: 12) {
                        ForEach(selectionKey.sorted(), id: \.self) { key in
                            let keyText: LocalizedStringKey = key.isOnRightSide ?
                                "Right \(Image(systemName: key.systemImage ?? "exclamationmark.circle.fill"))" :
                                "Left \(Image(systemName: key.systemImage ?? "exclamationmark.circle.fill"))"

                            Text(keyText)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .fixedSize(horizontal: true, vertical: false)

                            if key != selectionKey.sorted().last {
                                Divider()
                                    .padding(1)
                            }
                        }
                    }
                }
            }
            .modifier(ShakeEffect(shakes: shouldShake ? 2 : 0))
            .animation(Animation.default, value: shouldShake)
            .popover(isPresented: $tooManyKeysPopup, arrowEdge: .bottom) {
                Text("You can only use up to \(keyLimit) keys in your trigger key.")
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
            .onChange(of: validCurrentKey) { _ in
                if selectionKey != validCurrentKey {
                    selectionKey = validCurrentKey
                }
            }

            .fixedSize()
            .buttonStyle(LuminareCompactButtonStyle())

            Spacer()

            Button("Change") {
                guard !isActive else { return }
                startObservingKeys()
            }
            .buttonStyle(LuminareCompactButtonStyle())
            .fixedSize()
        }
    }

    func startObservingKeys() {
        selectionKey = []
        isActive = true

        // So that if doesn't interfere with the key detection here
        AppDelegate.loopManager.setFlagsObservers(scope: .global)

        eventMonitor = NSEventMonitor(scope: .local, eventMask: [.keyDown, .flagsChanged]) { event in
            // keyDown event is only used to track escape key
            if event.type == .keyDown, event.keyCode == CGKeyCode.kVK_Escape {
                finishedObservingKeys(wasForced: true)
            }

            if CGKeyCode.keyToImage.contains(where: { $0.key == event.keyCode.baseModifier }) {
                selectionKey.insert(event.keyCode)
            }

            // Backup system in case keys are pressed at the exact same time
            let flags = event.modifierFlags.convertToCGKeyCode()
            if flags.count != selectionKey.count {
                for key in flags where CGKeyCode.keyToImage.contains(where: { $0.key == key }) {
                    if !self.selectionKey.map(\.baseModifier).contains(key) {
                        self.selectionKey.insert(key)
                    }
                }
            }

            if event.modifierFlags.wasKeyUp, !selectionKey.isEmpty {
                finishedObservingKeys()
                return
            }

            if !event.modifierFlags.wasKeyUp, selectionKey.isEmpty {
                shouldShake.toggle()
            }
        }

        eventMonitor!.start()
        model.currentEventMonitor = eventMonitor
    }

    func finishedObservingKeys(wasForced: Bool = false) {
        var willSet = !wasForced

        if selectionKey.count > keyLimit {
            willSet = false
            shouldShake.toggle()
            tooManyKeysPopup = true
        }

        isActive = false

        if willSet {
            // Set the valid keybind to the current selected one
            validCurrentKey = selectionKey
        } else {
            // Set preview keybind back to previous one
            selectionKey = validCurrentKey
        }

        eventMonitor?.stop()
        eventMonitor = nil
        AppDelegate.loopManager.setFlagsObservers(scope: .all)
    }
}
