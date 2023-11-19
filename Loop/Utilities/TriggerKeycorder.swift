//
//  TriggerKeycorder.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-11.
//

import SwiftUI

struct TriggerKeycorder: View {
    @Binding private var validCurrentKey: TriggerKey
    @State private var selectionKey: TriggerKey?

    @State private var eventMonitor: NSEventMonitor?
    @State private var shouldShake: Bool = false
    @State private var isHovering: Bool = false
    @State private var suggestDisablingCapsLock: Bool = false
    @State private var isActive: Bool = false
    @State private var isCurrentlyPressed: Bool = false

    init(_ key: Binding<TriggerKey>) {
        self._validCurrentKey = key
        _selectionKey = State(initialValue: key.wrappedValue)
    }

    var body: some View {
        Button(action: {
            self.startObservingKeys()
        }, label: {
            HStack(spacing: 5) {
                if let symbol = selectionKey?.symbol {
                    Image(systemName: symbol)
                }
                Text(self.selectionKey?.name ?? "Click a modifier key...")
            }
            .fontDesign(.monospaced)
            .padding(5)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .foregroundStyle(.background.opacity(self.isActive ? 0.1 : 0.8))
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.tertiary.opacity(self.isHovering ? 1 : 0.5), lineWidth: 1)
                }
            }
        })
        .modifier(ShakeEffect(shakes: self.shouldShake ? 2 : 0))
        .animation(Animation.default, value: shouldShake)
        .popover(isPresented: $suggestDisablingCapsLock, arrowEdge: .bottom, content: {
            Text("Your Caps Lock key is on! Disable it to correctly assign a key.")
                .padding(8)
        })
        .onHover { hovering in
            self.isHovering = hovering
        }
        .buttonStyle(.plain)
        .scaleEffect(self.isCurrentlyPressed ? 0.9 : 1)
    }

    func startObservingKeys() {
        self.selectionKey = nil
        self.isActive = true
        self.eventMonitor = NSEventMonitor(scope: .local, eventMask: [.keyDown, .flagsChanged]) { event in
            // keyDown event is only used to track escape key
            if event.type == .keyDown && event.keyCode == CGKeyCode.kVK_Escape {
                finishedObservingKeys(wasForced: true)
            }

            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.capsLock) {
                self.suggestDisablingCapsLock = true
                self.selectionKey = nil
            } else {
                self.suggestDisablingCapsLock = false
                for key in TriggerKey.options where key.keycode == event.keyCode {
                    self.selectionKey = key
                    withAnimation(.snappy(duration: 0.1)) {
                        self.isCurrentlyPressed = true
                    }
                }
            }

            let keyUpValue = 256

            // on keyup
            if event.modifierFlags.rawValue == keyUpValue && self.selectionKey != nil {
                self.finishedObservingKeys()
                return
            }

            // on keydown
            if event.modifierFlags.rawValue != keyUpValue && self.selectionKey == nil {
                self.shouldShake.toggle()
            }
        }

        self.eventMonitor!.start()
    }

    func finishedObservingKeys(wasForced: Bool = false) {
        self.isActive = false
        withAnimation(.snappy(duration: 0.1)) {
            self.isCurrentlyPressed = false
        }

        if let selectionKey = self.selectionKey, !wasForced {
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
