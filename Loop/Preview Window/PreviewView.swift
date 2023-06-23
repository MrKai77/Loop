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

    @State var currentResizingDirection: WindowDirection = .noAction

    @Default(.useSystemAccentColor) var useSystemAccentColor
    @Default(.accentColor) var accentColor
    @Default(.useGradientAccentColor) var useGradientAccentColor
    @Default(.gradientAccentColor) var gradientAccentColor

    @Default(.previewVisibility) var previewVisibility
    @Default(.previewPadding) var previewPadding
    @Default(.previewCornerRadius) var previewCornerRadius
    @Default(.previewBorderThickness) var previewBorderThickness

    var body: some View {
        GeometryReader { geo in
            VStack {
                switch currentResizingDirection {
                case .bottomHalf, .bottomRightQuarter, .bottomLeftQuarter, .verticalCenterThird, .bottomThird, .bottomTwoThirds, .noAction:
                    Rectangle()
                        .frame(width: currentResizingDirection == .bottomThird ? geo.size.height / 3 * 2 : nil)
                default:
                    EmptyView()
                }

                HStack {
                    switch currentResizingDirection {
                    case .rightHalf, .topRightQuarter, .bottomRightQuarter, .horizontalCenterThird, .rightThird, .rightTwoThirds, .noAction:
                        Rectangle()
                            .frame(width: currentResizingDirection == .rightThird ? geo.size.width / 3 * 2 : nil)
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
                                        colors: [useSystemAccentColor ? Color.accentColor : accentColor,
                                                 useSystemAccentColor ? Color.accentColor :
                                                    (useGradientAccentColor ? gradientAccentColor : accentColor)]
                                    ),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: previewBorderThickness
                            )
                    }
                    .padding(previewPadding + previewBorderThickness/2)
                    .frame(width: currentResizingDirection == .noAction ? 0 : nil,
                           height: currentResizingDirection == .noAction ? 0 : nil)

                    switch currentResizingDirection {
                    case .leftHalf, .topLeftQuarter, .bottomLeftQuarter, .horizontalCenterThird, .leftThird, .leftTwoThirds, .noAction:
                        Rectangle()
                            .frame(width: currentResizingDirection == .leftThird ? geo.size.width / 3 * 2 : nil)
                    default:
                        EmptyView()
                    }
                }

                switch currentResizingDirection {
                case .topHalf, .topRightQuarter, .topLeftQuarter, .verticalCenterThird, .topThird, .topTwoThirds, .noAction:
                    Rectangle()
                        .frame(width: currentResizingDirection == .topThird ? geo.size.width / 3 * 2 : nil)
                default:
                    EmptyView()
                }
            }
        }
        .foregroundColor(.clear)
        .opacity(currentResizingDirection == .noAction ? 0 : 1)
        .animation(.interpolatingSpring(stiffness: 250, damping: 25), value: currentResizingDirection)
        .onReceive(.currentDirectionChanged) { obj in
            if !previewMode {
                if let direction = obj.userInfo?["Direction"] as? WindowDirection {
                    currentResizingDirection = direction
                }
            }
        }

        .onAppear {
            if previewMode {
                currentResizingDirection = .maximize
            }
        }
    }
}
