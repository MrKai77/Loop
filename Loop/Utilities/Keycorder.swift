//
//  Keycorder.swift
//  Loop
//
//  Created by Kai Azim on 2023-11-10.
//

import SwiftUI

struct Keycorder: View {
    @Binding private var validCurrentKeybind: Set<CGKeyCode>

    @State private var eventMonitor: NSEventMonitor?
    @State private var shouldShake: Bool = false
    @State private var isHovering: Bool = false

    @State private var selectionKeybind: Set<CGKeyCode>
    @State private var isActive: Bool = false

    init(key: Binding<Set<CGKeyCode>>) {
        self._validCurrentKeybind = key
        self.selectionKeybind = _validCurrentKeybind.wrappedValue
    }

    let activeAnimation = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
    let noAnimation = Animation.linear(duration: 0)

    var body: some View {
        Button(action: {
            self.startObservingKeys()
        }, label: {
            HStack(spacing: 5) {
                Text(self.selectionKeybind.description == "[]" ? "Press a key..." : self.selectionKeybind.description)
            }
            .padding(5)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .foregroundStyle(.background.opacity(self.isHovering ? 0.1 : self.isActive ? 0.1 : 0.8))
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
            }
        })
        .onHover { hovering in
            self.isHovering = hovering
        }
        .buttonStyle(.plain)
    }

    func startObservingKeys() {
        self.selectionKeybind = []
        self.isActive = true
        self.eventMonitor = NSEventMonitor(scope: .local, eventMask: [.keyDown, .keyUp]) { event in
            if event.type == .keyUp {
                if event.keyCode == CGKeyCode.kVK_Escape {
                    self.selectionKeybind = self.validCurrentKeybind
                } else {
                    self.validCurrentKeybind = self.selectionKeybind
                }

                self.finishedObservingKeys()
                return
            }

            if event.type == .keyDown {
                self.selectionKeybind.insert(event.keyCode)
            }
        }

        self.eventMonitor!.start()
    }

    func finishedObservingKeys() {
        self.isActive = false
        self.eventMonitor?.stop()
        self.eventMonitor = nil
    }
}
