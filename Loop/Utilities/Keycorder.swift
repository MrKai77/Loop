//
//  Keycorder.swift
//  Loop
//
//  Created by Kai Azim on 2023-11-10.
//

import SwiftUI
import Defaults
import Carbon.HIToolbox

struct Keycorder: View {
    @Binding private var validCurrentKeybind: Set<CGKeyCode>
    @State private var selectionKeybind: Set<CGKeyCode>

    @Binding private var direction: WindowDirection

    @State private var eventMonitor: NSEventMonitor?
    @State private var shouldShake: Bool = false
    @State private var shouldError: Bool = false
    @State private var errorMessage: String = ""

    @State private var isHovering: Bool = false
    @State private var isActive: Bool = false
    @State private var isCurrentlyPressed: Bool = false

    init(_ keybind: Binding<Keybind>) {
        self._validCurrentKeybind = keybind.keybind
        self._direction = keybind.direction
        self.selectionKeybind = _validCurrentKeybind.wrappedValue
    }

    let activeAnimation = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
    let noAnimation = Animation.linear(duration: 0)

    var body: some View {
        Button(action: {
            self.startObservingKeys()
        }, label: {
            HStack {
                if self.selectionKeybind.isEmpty {
                    Text(self.isActive ? "Press a key..." : "None")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 8)
                        .background {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .foregroundStyle(.background.opacity(self.isActive ? 0.1 : 0.8))
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.tertiary.opacity(self.isHovering ? 1 : 0.5), lineWidth: 1)
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                } else if let keys = self.selectionKeybind.humanReadable {
                    ForEach(keys, id: \.self) { key in
                        Text(key)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .aspectRatio(1, contentMode: .fill)
                            .background {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .foregroundStyle(.background.opacity(self.isActive ? 0.1 : 0.8))
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(.tertiary.opacity(self.isHovering ? 1 : 0.5), lineWidth: 1)
                                }
                            }
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .fontDesign(.monospaced)
        })
        .modifier(ShakeEffect(shakes: self.shouldShake ? 2 : 0))
        .animation(Animation.default, value: shouldShake)
        .popover(isPresented: $shouldError, arrowEdge: .bottom, content: {
            Text(self.errorMessage)
                .padding(8)
        })
        .onHover { hovering in
            self.isHovering = hovering
        }
        .buttonStyle(.plain)
        .scaleEffect(self.isCurrentlyPressed ? 0.9 : 1)
    }

    func startObservingKeys() {
        self.selectionKeybind = []
        self.isActive = true
        self.eventMonitor = NSEventMonitor(scope: .local, eventMask: [.keyDown, .keyUp, .flagsChanged]) { event in
            if event.type == .flagsChanged && event.keyCode.baseModifier == .kVK_Shift {
                self.selectionKeybind.insert(event.keyCode)
                withAnimation(.snappy(duration: 0.1)) {
                    self.isCurrentlyPressed = true
                }
            }

            if event.type == .keyUp {
                self.finishedObservingKeys()
                return
            }

            if event.type == .keyDown {
                if event.keyCode == CGKeyCode.kVK_Escape {
                    finishedObservingKeys(wasForced: true)
                }

                self.selectionKeybind.insert(event.keyCode)
                withAnimation(.snappy(duration: 0.1)) {
                    self.isCurrentlyPressed = true
                }

            }
        }

        self.eventMonitor!.start()
    }

    func finishedObservingKeys(wasForced: Bool = false) {
        self.isActive = false
        var willSet = !wasForced

        withAnimation(.snappy(duration: 0.1)) {
            self.isCurrentlyPressed = false
        }

        for keybind in Defaults[.keybinds] where (
            keybind.keybind == self.selectionKeybind && keybind.direction != self.direction
        ) {
            willSet = false
            self.shouldShake.toggle()
            self.shouldError = true
            self.errorMessage = "That keybind is already being used by \(keybind.direction.name.lowercased())."
            break
        }

        if willSet {
            // Set the valid keybind to the current selected one
            self.validCurrentKeybind = self.selectionKeybind
        } else {
            // Set preview keybind back to previous one
            self.selectionKeybind = self.validCurrentKeybind
        }

        self.eventMonitor?.stop()
        self.eventMonitor = nil
    }
}
