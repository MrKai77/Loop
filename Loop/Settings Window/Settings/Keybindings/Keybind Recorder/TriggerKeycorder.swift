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
    @EnvironmentObject private var model: KeybindsConfigurationModel
    @Environment(\.luminareAnimation) private var luminareAnimation
    @Default(.sideDependentTriggerKey) private var sideDependentTriggerKey

    let keyLimit: Int = 5

    @Binding private var validCurrentKey: Set<CGKeyCode>
    @State private var selectionKey: Set<CGKeyCode>

    @State private var eventMonitor: LocalEventMonitor?
    @State private var shouldShake: Bool = false
    @State private var isHovering: Bool = false
    @State private var isActive: Bool = false
    @State private var tooManyKeysPopup: Bool = false

    private var sortedKeys: [CGKeyCode] {
        let selectionKey: Set<CGKeyCode> = sideDependentTriggerKey ? selectionKey : selectionKey.baseModifiers
        return selectionKey.sorted()
    }

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
                        ForEach(sortedKeys, id: \.self) { key in
                            TriggerKeycorderKeyView(key: key)

                            if key != sortedKeys.last {
                                Divider()
                                    .padding(1)
                            }
                        }
                    }
                    .frame(height: 32)
                }
            }
            .modifier(ShakeEffect(shakes: shouldShake ? 2 : 0))
            .animation(luminareAnimation, value: sideDependentTriggerKey)
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
            .buttonStyle(.luminareCompact)

            Spacer()

            Button {
                guard !isActive else { return }
                startObservingKeys()
            } label: {
                Text("Change")
                    .frame(height: 32)
            }
            .buttonStyle(.luminareCompact)
            .fixedSize()
        }
        .luminareHorizontalPadding(12)
    }

    func startObservingKeys() {
        selectionKey = []
        isActive = true

        // So that if doesn't interfere with the key detection here
        LoopManager.shared.keybindObserver.stop()

        eventMonitor = LocalEventMonitor(events: [.keyDown, .flagsChanged]) { event in
            // keyDown event is only used to track escape key
            if event.keyCode == CGKeyCode.kVK_Escape {
                finishedObservingKeys(wasForced: true)
            }

            let flags = CGEventFlags(cocoaFlags: event.modifierFlags)
            let keycodes = flags.keyCodes
            selectionKey.formUnion(keycodes)

            if keycodes.isEmpty, !selectionKey.isEmpty {
                finishedObservingKeys()
                return nil
            }

            if !keycodes.isEmpty, selectionKey.isEmpty {
                shouldShake.toggle()
            }

            return nil
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

        LoopManager.shared.keybindObserver.start()
    }
}

struct TriggerKeycorderKeyView: View {
    @Default(.sideDependentTriggerKey) private var sideDependentTriggerKey
    private static let defaultIconName = "exclamationmark.circle.fill"
    let key: CGKeyCode

    var body: some View {
        HStack(spacing: 4) {
            let keyImage = Image(systemName: key.modifierSystemImage ?? Self.defaultIconName)

            if sideDependentTriggerKey {
                let side: String = key.isModifierOnRightSide
                    ? String(localized: "Right", comment: "Side of a trigger key")
                    : String(localized: "Left", comment: "Side of a trigger key")

                Text("\(side) \(keyImage)", comment: "Format for modifier key + side; %1$@ is the key (e.g. command), %2$@ is the side (left/right)")
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                keyImage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fixedSize(horizontal: true, vertical: false)
    }
}
