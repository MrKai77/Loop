//
//  TriggerKeycorder.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-11.
//

import SwiftUI
import Luminare

struct TriggerKeycorder: View {
    @EnvironmentObject private var data: KeybindsConfigurationData

    let keyLimit: Int = 5

    @Binding private var validCurrentKey: Set<CGKeyCode>
    @State private var selectionKey: Set<CGKeyCode>

    @State private var eventMonitor: NSEventMonitor?
    @State private var shouldShake: Bool = false
    @State private var isHovering: Bool = false
    @State private var isActive: Bool = false
    @State private var isCurrentlyPressed: Bool = false
    @State private var tooManyKeysPopup: Bool = false

    init(_ key: Binding<Set<CGKeyCode>>) {
        self._validCurrentKey = key
        _selectionKey = State(initialValue: key.wrappedValue)
    }

    var body: some View {
        Button {
            guard !self.isActive else { return }
            self.startObservingKeys()
        } label: {
            if self.selectionKey.isEmpty {
                Text(self.isActive ? "Set a trigger key…" : "None")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                HStack(spacing: 12) {
                    ForEach(self.selectionKey.sorted(), id: \.self) { key in
                        // swiftlint:disable:next line_length
                        Text("\(key.isOnRightSide ? String(localized: .init("Right", defaultValue: "Right")) : String(localized: .init("Left", defaultValue: "Left"))) \(Image(systemName: key.systemImage ?? "exclamationmark.circle.fill"))")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .fixedSize(horizontal: true, vertical: false)

                        if key != self.selectionKey.sorted().last {
                            Divider()
                                .padding(1)
                        }
                    }
                }
            }
        }
        .modifier(ShakeEffect(shakes: self.shouldShake ? 2 : 0))
        .animation(Animation.default, value: shouldShake)
        .popover(isPresented: $tooManyKeysPopup, arrowEdge: .bottom) {
            Text("You can only use up to \(keyLimit) keys in your trigger key.")
                .multilineTextAlignment(.center)
                .padding(8)
        }
        .onHover { hovering in
            self.isHovering = hovering
        }
        .onChange(of: data.eventMonitor) { _ in
            if data.eventMonitor != self.eventMonitor {
                self.finishedObservingKeys(wasForced: true)
            }
        }
        .onChange(of: self.validCurrentKey) { _ in
            if self.selectionKey != self.validCurrentKey {
                self.selectionKey = self.validCurrentKey
            }
        }

        .fixedSize()
        .buttonStyle(LuminareCompactButtonStyle())
    }

    func startObservingKeys() {
        self.selectionKey = []
        self.isActive = true

        self.eventMonitor = NSEventMonitor(scope: .local, eventMask: [.keyDown, .flagsChanged]) { event in
            // keyDown event is only used to track escape key
            if event.type == .keyDown && event.keyCode == CGKeyCode.kVK_Escape {
                finishedObservingKeys(wasForced: true)
            }

            if CGKeyCode.keyToImage.contains(where: { $0.key == event.keyCode.baseModifier }) {
                self.selectionKey.insert(event.keyCode)
                withAnimation(.snappy(duration: 0.1)) {
                    self.isCurrentlyPressed = true
                }
            }

            // Backup system in case keys are pressed at the exact same time
            let flags = event.modifierFlags.convertToCGKeyCode()
            if flags.count > 1 && !self.selectionKey.contains(flags) {
                for key in flags where CGKeyCode.keyToImage.contains(where: { $0.key == key }) {
                    if !self.selectionKey.map({ $0.baseModifier }).contains(key) {
                        self.selectionKey.insert(key)
                        withAnimation(.snappy(duration: 0.1)) {
                            self.isCurrentlyPressed = true
                        }
                    }
                }
            }

            if event.modifierFlags.wasKeyUp && !self.selectionKey.isEmpty {
                self.finishedObservingKeys()
                return
            }

            if !event.modifierFlags.wasKeyUp && self.selectionKey.isEmpty {
                self.shouldShake.toggle()
            }
        }

        self.eventMonitor!.start()
        data.eventMonitor = eventMonitor
    }

    func finishedObservingKeys(wasForced: Bool = false) {
        var willSet = !wasForced

        if self.selectionKey.count > self.keyLimit {
            willSet = false
            self.shouldShake.toggle()
            self.tooManyKeysPopup = true
        }

        self.isActive = false
        withAnimation(.snappy(duration: 0.1)) {
            self.isCurrentlyPressed = false
        }

        if willSet {
            // Set the valid keybind to the current selected one
            self.validCurrentKey = selectionKey
        } else {
            // Set preview keybind back to previous one
            self.selectionKey = self.validCurrentKey
        }

        self.eventMonitor?.stop()
        self.eventMonitor = nil
    }
}
