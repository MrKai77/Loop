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
    @Binding var windowAction: WindowAction
    @Binding var isPresented: Bool

    @State var action: WindowAction // this is so that onChange is called for each property

    @State private var currentTab: Tab = .position
    private enum Tab: CaseIterable {
        case position, size

        var name: String {
            switch self {
            case .position:
                "Position"
            case .size:
                "Size"
            }
        }

        var image: Image {
            switch self {
            case .position:
                Image(._18PxTableRows3Cols3)
            case .size:
                Image(._18PxSize)
            }
        }
    }

    let anchors: [CustomWindowActionAnchor] = [
        .topLeft, .top, .topRight,
        .left, .center, .right,
        .bottomLeft, .bottom, .bottomRight
    ]

    let previewController = PreviewController()
    let screenSize: CGSize

    init(action: Binding<WindowAction>, isPresented: Binding<Bool>) {
        self._windowAction = action
        self._isPresented = isPresented
        self._action = State(initialValue: action.wrappedValue)

        self.screenSize = NSScreen.main?.frame.size ?? NSScreen.screens[0].frame.size
    }

    var body: some View {
        ScreenView {
            GeometryReader { geo in
                let frame = action.getFrame(
                    window: nil,
                    bounds: .init(origin: .zero, size: geo.size),
                    isPreview: true
                )

                ZStack {
                    if action.sizeMode == .custom {
                        blurredWindow()
                            .frame(
                                width: frame.width,
                                height: frame.height
                            )
                            .offset(
                                x: frame.origin.x,
                                y: frame.origin.y
                            )
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .animation(.smooth(duration: 0.25), value: frame)
            }
        }

        LuminareSection {
            LuminareTextField(
                Binding(
                    get: {
                        action.name ?? ""
                    },
                    set: {
                        action.name = $0
                    }
                ),
                placeHolder: "Custom Keybind"
            )
        }

        LuminareSection {
            LuminarePicker(
                elements: Tab.allCases,
                selection: Binding(
                    get: {
                        currentTab
                    },
                    set: { newValue in
                        withAnimation(.smooth(duration: 0.25)) {
                            currentTab = newValue
                        }
                    }
                ),
                columns: 2,
                roundBottom: false
            ) { tab in
                HStack(spacing: 6) {
                    tab.image
                    Text(tab.name)
                }
                .fixedSize()
            }

            LuminareToggle(
                "Use pixels",
                isOn: Binding(
                    get: {
                        if action.unit == nil {
                            action.unit = .percentage
                        }
                        return action.unit == .pixels
                    },
                    set: { newValue in
                        withAnimation(.smooth(duration: 0.25)) {
                            if action.unit == .percentage {
                                action.width = min(action.width ?? 100, 100)
                                action.height = min(action.height ?? 100, 100)

                                action.xPoint = min(action.xPoint ?? 100, 100)
                                action.yPoint = min(action.yPoint ?? 100, 100)
                            }

                            action.unit = newValue ? .pixels : .percentage
                        }
                    }
                )
            )
        }

        if currentTab == .position {
            positionConfiguration()
        } else if currentTab == .size {
            sizeConfiguration()
        }

        HStack(spacing: 8) {
            Button("Preview") {}
                .onLongPressGesture(
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

            Button("Close") {
                isPresented = false
            }
        }
        .buttonStyle(LuminareCompactButtonStyle())
        .onChange(of: action) { _ in
            windowAction = action
        }
    }

    @ViewBuilder func positionConfiguration() -> some View {
        LuminareSection {
            LuminareToggle(
                "Use coordinates",
                isOn: Binding(
                    get: {
                        action.positionMode == .coordinates
                    },
                    set: { newValue in
                        withAnimation(.smooth(duration: 0.25)) {
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
                            withAnimation(.smooth(duration: 0.25)) {
                                action.anchor = newValue
                            }
                        }
                    ),
                    columns: 3,
                    roundTop: false
                ) { anchor in
                    IconView(action: .constant(anchor.iconAction))
                }

                if action.anchor ?? .center == .center || action.anchor == .macOSCenter {
                    LuminareToggle(
                        "Use macOS center",
                        isOn: Binding(
                            get: {
                                action.anchor == .macOSCenter
                            },
                            set: {
                                action.anchor = $0 ? .macOSCenter : .center
                            }
                        )
                    )
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
                    suffix: action.unit?.suffix ?? "",
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
                    suffix: action.unit?.suffix ?? "",
                    lowerClamp: true
                )
            }
        }
    }

    @ViewBuilder func sizeConfiguration() -> some View {
        LuminareSection {
            LuminarePicker(
                elements: CustomWindowActionSizeMode.allCases,
                selection: Binding(
                    get: {
                        action.sizeMode ?? .custom
                    },
                    set: { newValue in
                        withAnimation(.smooth(duration: 0.25)) {
                            action.sizeMode = newValue
                        }
                    }
                ),
                columns: 3,
                roundBottom: action.sizeMode != .custom
            ) { mode in
                VStack(spacing: 4) {
                    mode.image
                    Text(mode.name)
                }
                .padding(.vertical, 15)
            }

            if action.sizeMode ?? .custom == .custom {
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
                    suffix: action.unit?.suffix ?? "",
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
                    suffix: action.unit?.suffix ?? "",
                    lowerClamp: true
                )
            }
        }
    }

    @ViewBuilder
    func blurredWindow() -> some View {
        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 2)
            }
            .clipShape(.rect(cornerRadius: 5))
    }
}
