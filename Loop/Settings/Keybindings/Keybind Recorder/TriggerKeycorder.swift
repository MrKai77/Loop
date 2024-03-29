//
//  TriggerKeycorder.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-11.
//

import SwiftUI

struct TriggerKeycorder: View {
    @EnvironmentObject private var keycorderModel: KeycorderModel

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
        Button(action: {
            guard !self.isActive else { return }
            self.startObservingKeys()
        }, label: {
            HStack(spacing: 5) {
                if self.selectionKey.isEmpty {
                    Text(self.isActive ? "Set a trigger key..." : "None")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(5)
                        .padding(.horizontal, 8)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .foregroundStyle(.background)
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(
                                        .tertiary.opacity((self.isHovering || self.isActive) ? 1 : 0.5),
                                        lineWidth: 1
                                    )
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                } else {
                    ForEach(self.selectionKey.sorted(), id: \.self) { key in
                        // swiftlint:disable:next line_length
                        Text("\(key.isOnRightSide ? "Right" : "Left") \(Image(systemName: key.systemImage ?? "exclamationmark.circle.fill"))")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(5)
                            .background {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .foregroundStyle(.background)
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(.tertiary.opacity(self.isHovering ? 1 : 0.5), lineWidth: 1)
                                }
                            }
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .fontDesign(.monospaced)
            .contentShape(Rectangle())
        })
        .modifier(ShakeEffect(shakes: self.shouldShake ? 2 : 0))
        .animation(Animation.default, value: shouldShake)
        .popover(isPresented: $tooManyKeysPopup, arrowEdge: .bottom, content: {
            Text("You can only use up to \(keyLimit) keys in your trigger key.")
                .multilineTextAlignment(.center)
                .padding(8)
        })
        .onHover { hovering in
            self.isHovering = hovering
        }
        .onChange(of: keycorderModel.eventMonitor) { _ in
            if keycorderModel.eventMonitor != self.eventMonitor {
                self.finishedObservingKeys(wasForced: true)
            }
        }
        .onChange(of: self.validCurrentKey) { _ in
            if self.selectionKey != self.validCurrentKey {
                self.selectionKey = self.validCurrentKey
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(self.isCurrentlyPressed ? 0.9 : 1)
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
        keycorderModel.eventMonitor = eventMonitor
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
