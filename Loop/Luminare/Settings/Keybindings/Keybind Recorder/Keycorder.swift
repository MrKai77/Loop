//
//  Keycorder.swift
//  Loop
//
//  Created by Kai Azim on 2023-11-10.
//

import SwiftUI
import Luminare
import Defaults
import Carbon.HIToolbox

struct Keycorder: View {
    @EnvironmentObject private var keycorderModel: KeycorderModel

    let keyLimit: Int = 6

    @Default(.triggerKey) var triggerKey

    @Binding private var validCurrentKeybind: Set<CGKeyCode>
    @State private var selectionKeybind: Set<CGKeyCode>
    @Binding private var direction: WindowDirection

    @State private var eventMonitor: NSEventMonitor?
    @State private var shouldShake: Bool = false
    @State private var shouldError: Bool = false
    @State private var errorMessage: Text = Text("") // We use Text here for String interpolation with images

    @State private var isHovering: Bool = false
    @State private var isActive: Bool = false
    @State private var isCurrentlyPressed: Bool = false

    init(_ keybind: Binding<WindowAction>) {
        self._validCurrentKeybind = keybind.keybind
        self._direction = keybind.direction
        self._selectionKeybind = State(initialValue: keybind.wrappedValue.keybind)
    }

    let activeAnimation = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
    let noAnimation = Animation.linear(duration: 0)

    var body: some View {
        Button {
            guard !self.isActive else { return }
            self.startObservingKeys()
        } label: {
            if self.selectionKeybind.isEmpty {
                Text(self.isActive ? "\(Image(systemName: "ellipsis"))" : "\(Image(systemName: "exclamationmark.triangle"))")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: 27, height: 27)
                    .font(.callout)
                    .modifier(LuminareBordered())
            } else {
                HStack(spacing: 5) {
                    ForEach(self.selectionKeybind.sorted(), id: \.self) { key in
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
        .modifier(ShakeEffect(shakes: self.shouldShake ? 2 : 0))
        .animation(Animation.default, value: shouldShake)
        .popover(isPresented: $shouldError, arrowEdge: .bottom) {
            self.errorMessage
                .multilineTextAlignment(.center)
                .padding(8)
        }
        .onHover { hovering in
            self.isHovering = hovering
        }
        .onChange(of: keycorderModel.eventMonitor) { _ in
            if keycorderModel.eventMonitor != self.eventMonitor {
                self.finishedObservingKeys(wasForced: true)
            }
        }
        .onChange(of: self.validCurrentKeybind) { _ in
            if self.selectionKeybind != self.validCurrentKeybind {
                self.selectionKeybind = self.validCurrentKeybind
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    func startObservingKeys() {
        self.selectionKeybind = []
        self.isActive = true
        self.eventMonitor = NSEventMonitor(scope: .local, eventMask: [.keyDown, .keyUp, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                if !Defaults[.triggerKey].contains(where: { $0.baseModifier == event.keyCode.baseModifier }) {
                    self.shouldError = false
                    self.selectionKeybind.insert(event.keyCode.baseModifier)
                    withAnimation(.snappy(duration: 0.1)) {
                        self.isCurrentlyPressed = true
                    }
                } else {
                    if let systemImage = event.keyCode.baseModifier.systemImage {
                        // swiftlint:disable:next line_length
                        self.errorMessage = Text("\(Image(systemName: systemImage)) is already used as your trigger key.")
                    } else {
                        self.errorMessage = Text("That key is already used as your trigger key.")
                    }

                    self.shouldShake.toggle()
                    self.shouldError = true
                }
            }

            if event.type == .keyUp ||
               (event.type == .flagsChanged &&  !self.selectionKeybind.isEmpty && event.modifierFlags.rawValue == 256) {
                self.finishedObservingKeys()
                return
            }

            if event.type == .keyDown  && !event.isARepeat {
                if event.keyCode == CGKeyCode.kVK_Escape {
                    finishedObservingKeys(wasForced: true)
                    return
                }

                if (self.selectionKeybind.count + self.triggerKey.count) >= keyLimit {
                    self.errorMessage = Text(
                        "You can only use up to \(keyLimit) keys in a keybind, including the trigger key."
                    )
                    self.shouldShake.toggle()
                    self.shouldError = true
                } else {
                    self.shouldError = false
                    self.selectionKeybind.insert(event.keyCode)
                    withAnimation(.snappy(duration: 0.1)) {
                        self.isCurrentlyPressed = true
                    }
                }

            }
        }

        self.eventMonitor!.start()
        keycorderModel.eventMonitor = eventMonitor
    }

    func finishedObservingKeys(wasForced: Bool = false) {
        self.isActive = false
        var willSet = !wasForced

        withAnimation(.snappy(duration: 0.1)) {
            self.isCurrentlyPressed = false
        }

        if self.validCurrentKeybind == self.selectionKeybind {
            willSet = false
        }

        if willSet {
            for keybind in Defaults[.keybinds] where (
                keybind.keybind == self.selectionKeybind
            ) {
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
            self.validCurrentKeybind = self.selectionKeybind
        } else {
            // Set preview keybind back to previous one
            self.selectionKeybind = self.validCurrentKeybind
        }

        self.eventMonitor?.stop()
        self.eventMonitor = nil
    }
}
