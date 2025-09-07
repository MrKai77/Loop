//
//  CustomActionConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-27.
//

import Defaults
import Luminare
import SwiftUI

struct CustomActionConfigurationView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation
    @ObservedObject private var accentColorController: AccentColorController = .shared

    @Binding var windowAction: WindowAction
    @Binding var isPresented: Bool

    @State private var action: WindowAction
    @State private var currentTab: Tab = .position

    private enum Tab: LocalizedStringKey, CaseIterable {
        case position = "Position", size = "Size"

        var image: Image {
            switch self {
            case .position:
                Image(.tableRows3Cols3)
            case .size:
                Image(.frame)
            }
        }
    }

    private let anchors: [CustomWindowActionAnchor] = [
        .topLeft, .top, .topRight, .left, .center, .right, .bottomLeft, .bottom, .bottomRight
    ]

    private let previewController = PreviewController()
    private let screenSize: CGSize = NSScreen.main?.frame.size ?? NSScreen.screens[0].frame.size

    init(action: Binding<WindowAction>, isPresented: Binding<Bool>) {
        _windowAction = action
        _isPresented = isPresented
        _action = State(initialValue: action.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 12) {
            ScreenView(isBlurred: action.sizeMode != .custom) {
                GeometryReader { geo in
                    ZStack {
                        if action.sizeMode == .custom {
                            let frame = action.getFrame(
                                window: nil,
                                bounds: CGRect(origin: .zero, size: geo.size),
                                disablePadding: true
                            )

                            blurredWindow()
                                .frame(width: frame.width, height: frame.height)
                                .offset(x: frame.origin.x, y: frame.origin.y)
                                .animation(luminareAnimation, value: frame)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                }
            }
            .onChange(of: action) { windowAction = $0 }

            configurationSections()
            actionButtons()
        }
    }

    @ViewBuilder
    private func configurationSections() -> some View {
        LuminareSection(outerPadding: 0) {
            LuminareTextField(
                "Custom Keybind",
                text: Binding(
                    get: { action.name ?? "" },
                    set: { action.name = $0 }
                )
            )
            .luminareHasBackground(false)
            .luminareBordered(false)
            .luminareAspectRatio(contentMode: .fill)
        }

        LuminareSection(outerPadding: 0) {
            tabPicker()
            unitToggle()
        }

        Group {
            if currentTab == .position {
                positionConfiguration()
            } else {
                sizeConfiguration()
            }
        }
        .animation(luminareAnimation, value: action.unit)
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
                action.anchor = .center
            }
        }
    }

    @ViewBuilder
    private func tabPicker() -> some View {
        LuminarePicker(
            elements: Tab.allCases,
            selection: $currentTab.animation(luminareAnimation),
            columns: 2
        ) { tab in
            HStack(spacing: 6) {
                tab.image
                Text(tab.rawValue)
            }
            .fixedSize()
        }
        .luminarePickerRoundedCorner(top: .always)
        .frame(height: 40)
    }

    @ViewBuilder
    private func unitToggle() -> some View {
        LuminareToggle("Use pixels", isOn: Binding(get: { action.unit == .pixels }, set: { action.unit = $0 ? .pixels : .percentage }))
    }

    @ViewBuilder
    private func actionButtons() -> some View {
        HStack(spacing: 8) {
            Button("Preview") {}
                .onLongPressGesture(
                    // Allows for a press-and-hold gesture to show the preview
                    minimumDuration: 100.0,
                    maximumDistance: .infinity,
                    pressing: { pressing in
                        if pressing {
                            guard let screen = NSScreen.main else { return }
                            previewController.open(
                                screen: screen,
                                window: nil,
                                startingAction: action
                            )
                        } else {
                            previewController.close()
                        }
                    },
                    perform: {}
                )
                .disabled(action.sizeMode != .custom)

            Button("Close") { isPresented = false }
        }
        .luminareAspectRatio(contentMode: .fill)
        .buttonStyle(.luminareCompact)
    }

    @ViewBuilder
    private func positionConfiguration() -> some View {
        LuminareSection(outerPadding: 0) {
            LuminareToggle(
                "Use coordinates",
                isOn: Binding(
                    get: {
                        action.positionMode == .coordinates
                    },
                    set: { newValue in
                        withAnimation(luminareAnimation) {
                            action.positionMode = newValue ? .coordinates : .generic
                        }
                    }
                )
            )

            if action.positionMode ?? .generic == .generic {
                LuminarePicker(
                    elements: anchors,
                    selection: Binding(
                        get: {
                            // since center/macOS center use the same icon on the picker
                            if action.anchor == .macOSCenter {
                                return .center
                            }

                            return action.anchor ?? .center
                        },
                        set: { newValue in
                            withAnimation(luminareAnimation) {
                                action.anchor = newValue
                            }
                        }
                    ),
                    columns: 3
                ) { anchor in
                    IconView(action: anchor.iconAction)
                        .equatable()
                }
                .luminarePickerRoundedCorner(bottom: .always)

                if action.anchor ?? .center == .center || action.anchor == .macOSCenter {
                    LuminareToggle(
                        isOn: Binding(
                            get: {
                                action.anchor == .macOSCenter
                            },
                            set: {
                                action.anchor = $0 ? .macOSCenter : .center
                            }
                        )
                    ) {
                        Text("Use macOS center")
                            .padding(.trailing, 4)
                            .luminarePopover(attachedTo: .topTrailing) {
                                Text("macOS center places windows slightly above the absolute center,\nwhich can be found more ergonomic.")
                                    .padding(6)
                            }
                    }
                }
            } else {
                LuminareSlider(
                    "X",
                    value: Binding(
                        get: {
                            action.xPoint ?? 0
                        },
                        set: {
                            action.xPoint = $0
                        }
                    ),
                    in: action.unit == .percentage ? 0...100 : 0...Double(screenSize.width),
                    format: .number.precision(.fractionLength(0...0)),
                    clampsUpper: false,
                    suffix: Text(action.unit?.suffix ?? CustomWindowActionUnit.percentage.suffix)
                )

                LuminareSlider(
                    "Y",
                    value: Binding(
                        get: {
                            action.yPoint ?? 0
                        },
                        set: {
                            action.yPoint = $0
                        }
                    ),
                    in: action.unit == .percentage ? 0...100 : 0...Double(screenSize.height),
                    format: .number.precision(.fractionLength(0...0)),
                    clampsUpper: false,
                    suffix: Text(action.unit?.suffix ?? CustomWindowActionUnit.percentage.suffix)
                )
            }
        }
    }

    @ViewBuilder
    private func sizeConfiguration() -> some View {
        LuminareSection(outerPadding: 0) {
            LuminarePicker(
                elements: CustomWindowActionSizeMode.allCases,
                selection: Binding(
                    get: {
                        action.sizeMode ?? .custom
                    },
                    set: { newValue in
                        withAnimation(luminareAnimation) {
                            action.sizeMode = newValue
                        }
                    }
                ),
                columns: 3
            ) { mode in
                VStack(spacing: 4) {
                    mode.image
                    Text(mode.name)
                }
                .padding(.vertical, 15)
                .compositingGroup()
            }
            .luminarePickerRoundedCorner(top: .always, bottom: action.sizeMode == .custom ? .never : .always)

            if action.sizeMode ?? .custom == .custom {
                LuminareSlider(
                    "Width",
                    value: Binding(
                        get: {
                            action.width ?? 100
                        },
                        set: {
                            action.width = $0
                        }
                    ),
                    in: action.unit == .percentage ? 0...100 : 0...Double(screenSize.width),
                    format: .number.precision(.fractionLength(0...0)),
                    clampsUpper: false,
                    suffix: .init(action.unit?.suffix ?? CustomWindowActionUnit.percentage.suffix)
                )

                LuminareSlider(
                    "Height",
                    value: Binding(
                        get: {
                            action.height ?? 100
                        },
                        set: {
                            action.height = $0
                        }
                    ),
                    in: action.unit == .percentage ? 0...100 : 0...Double(screenSize.height),
                    format: .number.precision(.fractionLength(0...0)),
                    clampsUpper: false,
                    suffix: .init(action.unit?.suffix ?? CustomWindowActionUnit.percentage.suffix)
                )
            }
        }
    }

    @ViewBuilder
    private func blurredWindow() -> some View {
        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
            .overlay {
                RoundedRectangle(cornerRadius: 12 - 5)
                    .strokeBorder(accentColorController.color1, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12 - 5))
    }
}
