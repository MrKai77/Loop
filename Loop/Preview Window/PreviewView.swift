//
//  PreviewView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults

struct PreviewView: View {

    @State var currentKeybind: Keybind
    private let window: Window?
    private let previewMode: Bool

    init(previewMode: Bool = false, window: Window?, startingAction: Keybind = .init(.noAction)) {
        self.window = window
        self.previewMode = previewMode
        self._currentKeybind = State(initialValue: startingAction)
    }

    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor
    @Default(.useGradient) var useGradient
    @Default(.gradientColor) var gradientColor

    @Default(.previewVisibility) var previewVisibility
    @Default(.previewPadding) var previewPadding
    @Default(.windowPadding) var windowPadding
    @Default(.previewCornerRadius) var previewCornerRadius
    @Default(.previewBorderThickness) var previewBorderThickness
    @Default(.animationConfiguration) var animationConfiguration

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .mask(RoundedRectangle(cornerRadius: previewCornerRadius).foregroundColor(.white))
                    .shadow(radius: 10)
                RoundedRectangle(cornerRadius: previewCornerRadius)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(
                                colors: [
                                    Color.getLoopAccent(tone: .normal),
                                    Color.getLoopAccent(tone: useGradient ? .darker : .normal)
                                ]
                            ),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: previewBorderThickness
                    )
            }
            .padding(windowPadding + previewPadding + previewBorderThickness / 2)

            .frame(
                width: self.currentKeybind.previewWindowWidth(geo.size.width),
                height: self.currentKeybind.previewWindowHeight(geo.size.height)
            )

            .offset(
                x: self.currentKeybind.previewWindowXOffset(geo.size.width),
                y: self.currentKeybind.previewWindowYOffset(geo.size.height)
            )
        }
        .opacity(currentKeybind.direction == .noAction ? 0 : 1)
        .animation(animationConfiguration.previewWindowAnimation, value: currentKeybind)
        .onReceive(.directionChanged) { obj in
            if !self.previewMode, let keybind = obj.userInfo?["keybind"] as? Keybind, !keybind.direction.cyclable {
                self.currentKeybind = keybind

                if self.currentKeybind.direction == .undo && self.window != nil {
                    self.currentKeybind = WindowRecords.getLastDirection(for: self.window!)
                }
            }
        }
        .onAppear {
            if self.previewMode {
                self.currentKeybind = .init(.maximize)
            }
        }
    }
}
