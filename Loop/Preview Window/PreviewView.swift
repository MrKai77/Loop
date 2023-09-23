//
//  PreviewView.swift
//  Loop
//
//  Created by Kai Azim on 2023-01-24.
//

import SwiftUI
import Defaults

struct PreviewView: View {

    // Used to preview inside the app's settings
    @State var previewMode = false

    @State var currentResizeDirection: WindowDirection = .noAction

    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.customAccentColor) var customAccentColor
    @Default(.useGradient) var useGradient
    @Default(.gradientColor) var gradientColor

    @Default(.previewVisibility) var previewVisibility
    @Default(.previewPadding) var previewPadding
    @Default(.previewCornerRadius) var previewCornerRadius
    @Default(.previewBorderThickness) var previewBorderThickness

    var body: some View {
        GeometryReader { geo in
            VStack {
                switch currentResizeDirection {
                case .bottomHalf,
                        .bottomRightQuarter,
                        .bottomLeftQuarter,
                        .verticalCenterThird,
                        .bottomThird,
                        .bottomTwoThirds,
                        .noAction,
                        .lastDirection:
                    Rectangle()
                        .frame(height: currentResizeDirection == .bottomThird ? geo.size.height / 3 * 2 : nil)
                default:
                    EmptyView()
                }

                HStack {
                    switch currentResizeDirection {
                    case .rightHalf,
                            .topRightQuarter,
                            .bottomRightQuarter,
                            .horizontalCenterThird,
                            .rightThird,
                            .rightTwoThirds,
                            .noAction,
                            .lastDirection:
                        Rectangle()
                            .frame(width: currentResizeDirection == .rightThird ? geo.size.width / 3 * 2 : nil)
                    default:
                        EmptyView()
                    }

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
                    .padding(previewPadding + previewBorderThickness/2)
                    .frame(width: currentResizeDirection == .noAction ? 0 : nil,
                           height: currentResizeDirection == .noAction ? 0 : nil)
                    .frame(width: currentResizeDirection == .lastDirection ? 0 : nil,
                           height: currentResizeDirection == .lastDirection ? 0 : nil)
                    .frame(width: currentResizeDirection == .topTwoThirds ? geo.size.height / 3 * 2 : nil)
                    .frame(width: currentResizeDirection == .bottomTwoThirds ? geo.size.height / 3 * 2 : nil)
                    .frame(width: currentResizeDirection == .rightTwoThirds ? geo.size.width / 3 * 2 : nil)
                    .frame(width: currentResizeDirection == .leftTwoThirds ? geo.size.width / 3 * 2 : nil)

                    switch currentResizeDirection {
                    case .leftHalf,
                            .topLeftQuarter,
                            .bottomLeftQuarter,
                            .horizontalCenterThird,
                            .leftThird,
                            .leftTwoThirds,
                            .noAction,
                            .lastDirection:
                        Rectangle()
                            .frame(width: currentResizeDirection == .leftThird ? geo.size.width / 3 * 2 : nil)
                    default:
                        EmptyView()
                    }
                }

                switch currentResizeDirection {
                case .topHalf,
                        .topRightQuarter,
                        .topLeftQuarter,
                        .verticalCenterThird,
                        .topThird,
                        .topTwoThirds,
                        .noAction,
                        .lastDirection:
                    Rectangle()
                        .frame(height: currentResizeDirection == .topThird ? geo.size.width / 3 * 2 : nil)
                default:
                    EmptyView()
                }
            }
        }
        .foregroundColor(.clear)
        .opacity(currentResizeDirection == .noAction ? 0 : 1)
        .scaleEffect(currentResizeDirection == .center ? 0.8 : 1)
        .animation(.interpolatingSpring(stiffness: 250, damping: 25), value: currentResizeDirection)
        .onReceive(.directionChanged) { obj in
            if !previewMode {
                if let direction = obj.userInfo?["direction"] as? WindowDirection {
                    currentResizeDirection = direction
                }
            }
        }

        .onAppear {
            if previewMode {
                currentResizeDirection = .maximize
            }
        }
    }
}
