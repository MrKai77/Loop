//
//  Keycorder.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-11.
//

import SwiftUI

struct Keycorder: View {
    @State private var validCurrentKey: Binding<TriggerKey>
    private let onChange: (NSEvent) -> TriggerKey?

    @State private var eventMonitor: NSEventMonitor?
    @State private var shouldShake: Bool = false
    @State private var isHovering: Bool = false

    @State private var selectionKey: TriggerKey?
    @State private var isActive: Bool = false

    init(
        key: Binding<TriggerKey>,
        onChange: @escaping (NSEvent) -> (TriggerKey?)) {
            self.validCurrentKey = key
            self.selectionKey = key.wrappedValue
            self.onChange = onChange
    }

    let activeAnimation = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
    let noAnimation = Animation.linear(duration: 0)

    var body: some View {
        Button(action: {
            self.selectionKey = nil
        }, label: {
            HStack(spacing: 5) {
                if let symbol = selectionKey?.symbol {
                    Image(systemName: symbol)
                }
                Text(self.selectionKey?.name ?? "Click a modifier key...")

                Image(systemName: "xmark")
                    .fontWeight(.bold)
                    .scaleEffect(0.7)
                    .foregroundStyle(.white)
                    .padding(1)
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .foregroundStyle(.quaternary)
                            .opacity(!(self.isHovering || self.isActive) ? 1 : 0)
                    }
            }
            .padding(2)
            .padding(.leading, 5)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .foregroundStyle(.secondary.shadow(.inner(color: .white, radius: 0, x: 0, y: 0.5)))
                    .shadow(color: .black, radius: 0.5, x: 0, y: 1)
                    .opacity(0.5)
                    .opacity(isActive ? 0.5 : 1)
                    .animation(isActive ? activeAnimation : noAnimation, value: isActive)
                    .opacity((self.isHovering || self.isActive) ? 1 : 0)
            }
        })
        .modifier(ShakeEffect(shakes: self.shouldShake ? 2 : 0))
        .animation(Animation.default, value: shouldShake)
        .onHover { hovering in
            self.isHovering = hovering
        }
        .buttonStyle(.plain)
        .onChange(of: self.selectionKey) { _ in
            if self.selectionKey == nil {
                self.startObservingKeys()
            }
        }
    }

    func startObservingKeys() {
        self.isActive = true
        self.eventMonitor = NSEventMonitor(scope: .local, eventMask: .flagsChanged) { event in
            self.selectionKey = self.onChange(event)
            let keyUpValue = 256

            if event.modifierFlags.rawValue == keyUpValue && self.selectionKey != nil {
                self.finishedObservingKeys()
                return
            }

            if event.modifierFlags.rawValue != keyUpValue && self.selectionKey == nil {
                self.shouldShake.toggle()
            }

            if let key = selectionKey {
                self.validCurrentKey.wrappedValue = key
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

struct ShakeEffect: GeometryEffect {
    func effectValue(size: CGSize) -> ProjectionTransform {
        return ProjectionTransform(
            CGAffineTransform(
                translationX: 3 * sin(position * 3 * .pi),
                y: 0
            )
        )
    }

    init(shakes: Int) {
        position = CGFloat(shakes)
    }

    var position: CGFloat
    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }
}
