//
//  StashActionConfigurationView.swift
//  Loop
//
//  Created by Guillaume Clédat on 19/06/2025.
//

import Defaults
import Foundation
import Luminare
import SwiftUI

struct StashActionConfigurationView: View {
    @Binding var windowAction: WindowAction
    @Binding var isPresented: Bool

    @State private var action: WindowAction
    @State private var currentTab: Tab = .position

    private enum Tab: LocalizedStringKey, CaseIterable {
        case position = "Position", size = "Unstashed Size"

        var image: Image {
            switch self {
            case .position:
                Image(._18PxTableRows3Cols3)
            case .size:
                Image(._18PxSize)
            }
        }
    }

    private let defaultAnchor: CustomWindowActionAnchor = .topLeft

    private var anchors: [CustomWindowActionAnchor] {
        [.topLeft, .topRight, .left, .right, .bottomLeft, .bottomRight]
    }

    private var sizeModes: [CustomWindowActionSizeMode] {
        [.custom, .preserveSize]
    }

    private let previewController = PreviewController()
    private let screenSize: CGSize = NSScreen.main?.frame.size ?? NSScreen.screens[0].frame.size

    init(action: Binding<WindowAction>, isPresented: Binding<Bool>) {
        _windowAction = action
        _isPresented = isPresented
        _action = State(initialValue: action.wrappedValue)
    }

    var body: some View {
        ScreenView(blurred: .constant(action.sizeMode != .custom)) {
            GeometryReader { geo in
                ZStack {
                    if action.sizeMode == .custom {
                        let frame = action.getFrame(window: nil, bounds: CGRect(origin: .zero, size: geo.size), disablePadding: true)

                        blurredWindow()
                            .frame(width: frame.width, height: frame.height)
                            .offset(x: frame.origin.x, y: frame.origin.y)
                            .animation(LuminareConstants.animation, value: frame)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
        }
        .onChange(of: action) { windowAction = $0 }

        configurationSections()
        actionButtons()
    }

    @ViewBuilder private func configurationSections() -> some View {
        LuminareSection {
            LuminareTextField("Custom Keybind", text: Binding(get: { action.name ?? "" }, set: { action.name = $0 }))
        }

        LuminareSection {
            tabPicker()
        }

        Group {
            if currentTab == .position {
                positionConfiguration()
            } else {
                sizeConfiguration()
            }
        }
        .animation(LuminareConstants.animation, value: action.unit)
        .onAppear {
            if action.unit == nil {
                action.unit = .percentage
            }

            if action.sizeMode == nil {
                action.sizeMode = .custom
            }

            if action.width == nil {
                action.width = 80
            }

            if action.height == nil {
                action.height = 80
            }

            if action.positionMode == nil {
                action.positionMode = .generic
            }

            if action.anchor == nil {
                action.anchor = defaultAnchor
            }
        }
    }

    @ViewBuilder private func tabPicker() -> some View {
        LuminarePicker(elements: Tab.allCases, selection: $currentTab, columns: 2, roundBottom: true) { tab in
            HStack(spacing: 6) {
                tab.image
                Text(tab.rawValue)
            }
            .fixedSize()
        }
    }

    @ViewBuilder private func unitToggle() -> some View {
        LuminareToggle("Use pixels", isOn: Binding(get: { action.unit == .pixels }, set: { action.unit = $0 ? .pixels : .percentage }))
    }

    @ViewBuilder private func actionButtons() -> some View {
        HStack(spacing: 8) {
            Button("Preview") {}
                .onLongPressGesture( // Allows for a press-and-hold gesture to show the preview
                    minimumDuration: 100.0,
                    maximumDistance: .infinity,
                    pressing: { pressing in
                        if pressing {
                            guard let screen = NSScreen.main else { return }
                            previewController.open(screen: screen, startingAction: action)
                        } else {
                            previewController.close()
                        }
                    },
                    perform: {}
                )
                .disabled(action.sizeMode != .custom)

            Button("Close") { isPresented = false }
        }
        .buttonStyle(LuminareCompactButtonStyle())
    }

    @ViewBuilder private func positionConfiguration() -> some View {
        LuminareSection {
            if action.positionMode ?? .generic == .generic {
                LuminarePicker(
                    elements: anchors,
                    selection: Binding(
                        get: {
                            action.anchor ?? defaultAnchor
                        },
                        set: { newValue in
                            withAnimation(LuminareConstants.animation) {
                                action.anchor = newValue
                            }
                        }
                    ),
                    columns: action.direction == .stash ? 2 : 3,
                    roundTop: false
                ) { anchor in
                    IconView(action: anchor.iconAction)
                }
            } else {
                LuminareValueAdjuster(
                    "X",
                    value: Binding(
                        get: {
                            action.xPoint ?? 0
                        },
                        set: {
                            action.xPoint = $0
                        }
                    ),
                    sliderRange: action.unit == .percentage ?
                        0...100 :
                        0...Double(screenSize.width),
                    suffix: .init(action.unit?.suffix ?? CustomWindowActionUnit.percentage.suffix),
                    lowerClamp: true
                )

                LuminareValueAdjuster(
                    "Y",
                    value: Binding(
                        get: {
                            action.yPoint ?? 0
                        },
                        set: {
                            action.yPoint = $0
                        }
                    ),
                    sliderRange: action.unit == .percentage ?
                        0...100 :
                        0...Double(screenSize.height),
                    suffix: .init(action.unit?.suffix ?? CustomWindowActionUnit.percentage.suffix),
                    lowerClamp: true
                )
            }
        }
    }

    @ViewBuilder private func sizeConfiguration() -> some View {
        LuminareSection {
            LuminarePicker(
                elements: sizeModes,
                selection: Binding(
                    get: {
                        action.sizeMode ?? .custom
                    },
                    set: { newValue in
                        withAnimation(LuminareConstants.animation) {
                            action.sizeMode = newValue
                        }
                    }
                ),
                columns: sizeModes.count,
                roundBottom: action.sizeMode != .custom
            ) { mode in
                VStack(spacing: 4) {
                    mode.image
                    Text(mode.name)
                }
                .padding(.vertical, 15)
            }

            if action.sizeMode ?? .custom == .custom {
                unitToggle()

                LuminareValueAdjuster(
                    "Width",
                    value: Binding(
                        get: {
                            action.width ?? 100
                        },
                        set: {
                            action.width = $0
                        }
                    ),
                    sliderRange: action.unit == .percentage ?
                        0...100 :
                        0...Double(screenSize.width),
                    suffix: .init(action.unit?.suffix ?? CustomWindowActionUnit.percentage.suffix),
                    lowerClamp: true
                )

                LuminareValueAdjuster(
                    "Height",
                    value: Binding(
                        get: {
                            action.height ?? 100
                        },
                        set: {
                            action.height = $0
                        }
                    ),
                    sliderRange: action.unit == .percentage ?
                        0...100 :
                        0...Double(screenSize.width),
                    suffix: .init(action.unit?.suffix ?? CustomWindowActionUnit.percentage.suffix),
                    lowerClamp: true
                )
            }
        }
    }

    @ViewBuilder private func blurredWindow() -> some View {
        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
            .overlay {
                RoundedRectangle(cornerRadius: 12 - 5)
                    .strokeBorder(Color.getLoopAccent(tone: .normal), lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12 - 5))
    }
}
