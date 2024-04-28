//
//  CustomKeybindConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-27.
//

import SwiftUI
import Luminare
import Defaults

struct CustomKeybindConfigurationView: View {
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
                Image(systemName: "scope")
            case .size:
                Image(systemName: "square.resize")
            }
        }
    }

    let anchors: [CustomWindowActionAnchor] = [
        .topLeft, .top, .topRight,
        .left, .center, .right,
        .bottomLeft, .bottom, .bottomRight
    ]

    let previewController = PreviewController()

    init(action: Binding<WindowAction>, isPresented: Binding<Bool>) {
        self._windowAction = action
        self._isPresented = isPresented
        self._action = State(initialValue: action.wrappedValue)
    }

    var body: some View {
        ScreenView {
//            PaddingPreviewView($paddingModel)
        }
        .onChange(of: self.action) { _ in
            windowAction = action
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
                        withAnimation(.smooth(duration: 0.3)) {
                            currentTab = newValue
                        }
                    }
                ),
                columns: 2,
                roundBottom: false
            ) { tab in
                Text("\(tab.image) \(tab.name)")
            }

            LuminareToggle(
                "Use pixels",
                isOn: Binding(
                    get: {
                        action.unit == .pixels
                    },
                    set: {
                        action.unit = $0 ? .pixels : .percentage
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
            Button("Preview") { }
                .onLongPressGesture(
                    minimumDuration: 100.0,
                    maximumDistance: .infinity,
                    pressing: { pressing in
                        if pressing {
                            guard let screen = NSScreen.main else { return }
                            previewController.open(screen: screen, startingAction: self.action)
                        } else {
                            previewController.close()
                        }
                    },
                    perform: { }
                )

            Button("Save & Close") {
                isPresented = false
            }
        }
        .buttonStyle(LuminareCompactButtonStyle())
    }

    @ViewBuilder func positionConfiguration() -> some View {
        LuminareSection {
            LuminareToggle(
                "Use coordinates",
                isOn: Binding(
                    get: {
                        action.positionMode == .coordinates
                    },
                    set: {
                        action.positionMode = $0 ? .coordinates : .generic
                    }
                )
            )

            LuminarePicker(
                elements: anchors,
                selection: Binding(
                    get: {
                        if action.anchor == nil {
                            action.anchor = .center
                        }

                        if action.anchor == .macOSCenter {
                            return .center
                        }

                        return action.anchor ?? .center
                    },
                    set: { newValue in
                        withAnimation(.smooth(duration: 0.3)) {
                            action.anchor = newValue
                        }
                    }
                ),
                columns: 3
            ) { anchor in
                anchor.image
            }

            if action.anchor == .center || action.anchor == .macOSCenter {
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
        }
    }

    @ViewBuilder func sizeConfiguration() -> some View {
        LuminareSection {
            LuminarePicker(
                elements: CustomWindowActionSizeMode.allCases,
                selection: Binding(
                    get: {
                        if action.sizeMode == nil {
                            action.sizeMode = .custom
                        }
                        return action.sizeMode ?? .custom
                    },
                    set: { newValue in
                        withAnimation(.smooth(duration: 0.3)) {
                            action.sizeMode = newValue
                        }
                    }
                ),
                columns: 3,
                roundBottom: action.sizeMode != .custom
            ) { mode in
                VStack(spacing: 5) {
                    mode.image
                    Text(mode.name)
                }
                .padding(.vertical, 15)
            }

            if action.sizeMode == .custom {
                LuminareValueAdjuster(
                    "Width",
                    value: Binding(
                        get: {
                            if action.width == nil {
                                action.width = 100
                            }
                            return action.width ?? 100
                        },
                        set: {
                            action.width = $0
                        }
                    ),
                    sliderRange: 0...100,
                    suffix: action.unit?.suffix ?? "",
                    lowerClamp: true
                )

                LuminareValueAdjuster(
                    "Height",
                    value: Binding(
                        get: {
                            if action.height == nil {
                                action.height = 100
                            }
                            return action.height ?? 100
                        },
                        set: {
                            action.height = $0
                        }
                    ),
                    sliderRange: 0...100,
                    suffix: action.unit?.suffix ?? "",
                    lowerClamp: true
                )
            }
        }
    }
}
