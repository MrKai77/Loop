//
//  PreviewView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults

struct PreviewView: View {

    @State var currentAction: WindowAction
    private let window: Window?
    private let previewMode: Bool

    init(
        previewMode: Bool = false,
        window: Window?,
        startingAction: WindowAction = .init(.noAction)
    ) {
        self.window = window
        self.previewMode = previewMode
        self._currentAction = State(initialValue: startingAction)
    }

    @Default(.useGradient) var useGradient
    @Default(.previewPadding) var previewPadding
    @Default(.padding) var padding
    @Default(.previewCornerRadius) var previewCornerRadius
    @Default(.previewBorderThickness) var previewBorderThickness
    @Default(.animationConfiguration) var animationConfiguration

    @State var windowEdgesToPad: Edge.Set = []

    var body: some View {
        GeometryReader { _ in
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
            .padding(previewPadding + previewBorderThickness / 2)
            .padding(windowEdgesToPad, padding.window / 2)

            .frame(
                width: self.currentAction.getFrame(window: self.window).width,
                height: self.currentAction.getFrame(window: self.window).height
            )
            .offset(
                x: self.currentAction.getFrame(window: self.window).minX,
                y: self.currentAction.getFrame(window: self.window).minY
            )

            .padding(.top, padding.totalTopPadding)
            .padding(.bottom, padding.bottom)
            .padding(.leading, padding.left)
            .padding(.trailing, padding.right)

            .opacity(currentAction.direction == .noAction ? 0 : 1)
            .animation(animationConfiguration.previewWindowAnimation, value: currentAction)
            .onReceive(.updateUIDirection) { obj in
                if !self.previewMode,
                   let action = obj.userInfo?["action"] as? WindowAction,
                   !action.direction.isPresetCyclable,
                   !action.direction.willChangeScreen,
                   action.direction != .cycle {

                    self.currentAction = action

                    if self.currentAction.direction == .undo && self.window != nil {
                        self.currentAction = WindowRecords.getLastAction(for: self.window!)
                    }

                    print("New preview window action recieved: \(action.direction)")
                }
            }
            .onAppear {
                if self.previewMode {
                    self.currentAction = .init(.maximize)
                }

                self.windowEdgesToPad = Edge.Set.all.subtracting(
                    self.currentAction.getEdgesTouchingScreen()
                )
            }
            .onChange(of: self.currentAction.getEdgesTouchingScreen()) { _ in
                self.windowEdgesToPad = Edge.Set.all.subtracting(
                    self.currentAction.getEdgesTouchingScreen()
                )
            }
        }
    }
}
