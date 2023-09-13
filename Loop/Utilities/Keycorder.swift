//
//  Keycorder.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-11.
//

import SwiftUI

struct Keycorder: View {
    private let label: String
    @State private var validCurrentKey: Binding<TriggerKey>
    private let onChange: (NSEvent) -> TriggerKey?

    @State private var eventMonitor: EventMonitor?
    @State private var shouldShake: Bool = false
    @State private var isHovering: Bool = false

    @State private var selectionKey: TriggerKey?
    @State private var isActive: Bool = false

    init(
        _ label: String,
        key: Binding<TriggerKey>,
        onChange: @escaping (NSEvent) -> (TriggerKey?)) {
            self.label = label
            self.validCurrentKey = key
            self.selectionKey = key.wrappedValue
            self.onChange = onChange
    }

    let activeAnimation = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
    let noAnimation = Animation.linear(duration: 0)

    var body: some View {
        HStack(spacing: 5) {
            Text(label)

            Spacer()

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
        }
        .buttonStyle(.plain)
        .onChange(of: self.selectionKey) { _ in
            if self.selectionKey == nil {
                self.isActive = true
            }
        }
        .onChange(of: self.isActive) { _ in
            if self.isActive {
                self.registerObserver()
            } else {
                self.unregisterObserver()
            }
        }
    }

    func registerObserver() {
        self.eventMonitor = EventMonitor(eventMask: .flagsChanged) { cgEvent in
            if let event = NSEvent(cgEvent: cgEvent) {
                self.selectionKey = self.onChange(event)

                if event.modifierFlags.rawValue == 256 && self.selectionKey != nil {
                    self.isActive = false
                    self.unregisterObserver()
                    print("------")
                    return Unmanaged.passRetained(cgEvent)
                }

                if self.selectionKey == nil {
                    self.shouldShake.toggle()    // This will trigger a shake animation
                }

                if let key = selectionKey {
                    self.validCurrentKey.wrappedValue = key
                }
            }

            return Unmanaged.passRetained(cgEvent)
        }

        self.eventMonitor!.start()
    }

    func unregisterObserver() {
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
