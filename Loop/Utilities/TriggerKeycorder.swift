//
//  TriggerKeycorder.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-11.
//

import SwiftUI

struct TriggerKeycorder: View {
    @Binding private var validCurrentKey: Set<CGKeyCode>
    @State private var selectionKey: Set<CGKeyCode>

    @State private var eventMonitor: NSEventMonitor?
    @State private var shouldShake: Bool = false
    @State private var isHovering: Bool = false
    @State private var suggestDisablingCapsLock: Bool = false
    @State private var isActive: Bool = false
    @State private var isCurrentlyPressed: Bool = false

    init(_ key: Binding<Set<CGKeyCode>>) {
        self._validCurrentKey = key
        _selectionKey = State(initialValue: key.wrappedValue)
    }

    var body: some View {
        Button(action: {
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
                    //                } else if let systemImages = self.selectionKey.systemImages {
                } else {
                    ForEach(self.selectionKey.sorted(), id: \.self) { key in
                        Text("\(key.isOnRightSide ? "Right" : "Left") \(Image(systemName: key.systemImage ?? "dash"))")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
//                            .aspectRatio(1, contentMode: .fill)
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
        self.selectionKey = []
        self.isActive = true
        self.eventMonitor = NSEventMonitor(scope: .local, eventMask: [.keyDown, .flagsChanged]) { event in
            // keyDown event is only used to track escape key
            if event.type == .keyDown && event.keyCode == CGKeyCode.kVK_Escape {
                finishedObservingKeys(wasForced: true)
            }

            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.capsLock) {
                self.suggestDisablingCapsLock = true
                self.selectionKey = []
            } else {
                self.suggestDisablingCapsLock = false
                if CGKeyCode.keyToImage.contains(where: { $0.key == event.keyCode.baseModifier }) {
                    self.selectionKey.insert(event.keyCode)
                    withAnimation(.snappy(duration: 0.1)) {
                        self.isCurrentlyPressed = true
                    }
                }
            }

            let keyUpValue = 256

            // on keyup
            if event.modifierFlags.rawValue == keyUpValue && !self.selectionKey.isEmpty {
                self.finishedObservingKeys()
                return
            }

            // on keydown
            if event.modifierFlags.rawValue != keyUpValue && self.selectionKey.isEmpty {
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

        if !wasForced {
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
