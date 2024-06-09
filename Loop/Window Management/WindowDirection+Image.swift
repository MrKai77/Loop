//
//  WindowDirection+Image.swift
//  Loop
//
//  Created by phlpsong on 2024/3/30.
//

import SwiftUI

extension WindowAction {
    @ViewBuilder
    func iconView() -> some View {
        let size = CGSize(width: 16, height: 12)

        RoundedRectangle(cornerRadius: 3)
            .stroke(lineWidth: 1.5)
            .frame(width: size.width + 2, height: size.height + 2)
            .overlay {
                if let icon = icon {
                    icon
                        .font(.system(size: 8))
                        .fontWeight(.bold)
                } else if direction == .cycle, let first = cycle?.first {
                    GeometryReader { geo in
                        let frame = first.getFrame(
                            window: nil,
                            bounds: .init(origin: .zero, size: geo.size),
                            applyPadding: false
                        )

                        ZStack {
                            RoundedRectangle(cornerRadius: 1)
                                .frame(
                                    width: frame.width,
                                    height: frame.height
                                )
                                .offset(
                                    x: frame.origin.x,
                                    y: frame.origin.y
                                )
                        }
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    }
                    .padding(2)
                } else {
                    GeometryReader { geo in
                        let frame = getFrame(
                            window: nil,
                            bounds: .init(origin: .zero, size: geo.size),
                            applyPadding: false
                        )

                        ZStack {
                            RoundedRectangle(cornerRadius: 1)
                                .frame(
                                    width: frame.width,
                                    height: frame.height
                                )
                                .offset(
                                    x: frame.origin.x,
                                    y: frame.origin.y
                                )
                        }
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                    }
                    .padding(2)
                }
            }
    }

    var icon: Image? {
        switch self.direction {
        case .noAction:
            Image(systemName: "questionMark")
        case .undo:
            Image(systemName: "arrow.uturn.backward")
        case .initialFrame:
            Image(systemName: "backward.end.alt.fill")
        case .hide:
            Image(systemName: "eye.slash.fill")
        case .minimize:
            Image(systemName: "arrow.down.right.and.arrow.up.left")
        case .nextScreen:
            Image(systemName: "forward.fill")
        case .previousScreen:
            Image(systemName: "backward.fill")
        case .larger:
            Image(systemName: "arrow.up.left.and.arrow.down.right")
        case .smaller:
            Image(systemName: "arrow.down.right.and.arrow.up.left")
        case .shrinkTop:
            Image(systemName: "arrow.down")
        case .shrinkBottom:
            Image(systemName: "arrow.up")
        case .shrinkRight:
            Image(systemName: "arrow.left")
        case .shrinkLeft:
            Image(systemName: "arrow.right")
        case .growTop:
            Image(systemName: "arrow.up")
        case .growBottom:
            Image(systemName: "arrow.down")
        case .growRight:
            Image(systemName: "arrow.right")
        case .growLeft:
            Image(systemName: "arrow.left")
        default:
            nil
        }
    }
//    var icon: Image? {
//        switch self {
//        case .maximize:
//            Image(systemName: "rectangle.inset.filled")
//        case .almostMaximize:
//            Image(systemName: "rectangle.center.inset.filled")
//        case .fullscreen:
//            Image(systemName: "rectangle.fill")
//        case .undo:
//            Image("custom.arrow.uturn.backward.rectangle")
//        case .initialFrame:
//            Image("custom.backward.end.alt.fill.2.rectangle")
//        case .hide:
//            Image("custom.rectangle.slash")
//        case .minimize:
//            Image("custom.arrow.down.right.and.arrow.up.left.rectangle")
//        case .center:
//            Image("custom.rectangle.center.inset.inset.filled")
//        case .macOSCenter:
//            Image("custom.rectangle.center.inset.inset.filled")
//
//        case .topHalf:
//            Image(systemName: "rectangle.tophalf.inset.filled")
//        case .rightHalf:
//            Image(systemName: "rectangle.righthalf.inset.filled")
//        case .bottomHalf:
//            Image(systemName: "rectangle.bottomhalf.inset.filled")
//        case .leftHalf:
//            Image(systemName: "rectangle.lefthalf.inset.filled")
//
//        case .topLeftQuarter:
//            Image(systemName: "rectangle.inset.topleft.filled")
//        case .topRightQuarter:
//            Image(systemName: "rectangle.inset.topright.filled")
//        case .bottomRightQuarter:
//            Image(systemName: "rectangle.inset.bottomright.filled")
//        case .bottomLeftQuarter:
//            Image(systemName: "rectangle.inset.bottomleft.filled")
//
//        case .rightThird:
//            Image(systemName: "rectangle.rightthird.inset.filled")
//        case .rightTwoThirds:
//            Image("custom.rectangle.righttwothirds.inset.filled")
//        case .horizontalCenterThird:
//            Image("custom.rectangle.horizontalcenterthird.inset.filled")
//        case .leftThird:
//            Image(systemName: "rectangle.leftthird.inset.filled")
//        case .leftTwoThirds:
//            Image("custom.rectangle.lefttwothirds.inset.filled")
//
//        case .topThird:
//            Image(systemName: "rectangle.topthird.inset.filled")
//        case .topTwoThirds:
//            Image("custom.rectangle.toptwothirds.inset.filled")
//        case .verticalCenterThird:
//            Image("custom.rectangle.verticalcenterthird.inset.filled")
//        case .bottomThird:
//            Image(systemName: "rectangle.bottomthird.inset.filled")
//        case .bottomTwoThirds:
//            Image("custom.rectangle.bottomtwothirds.inset.filled")
//
//        case .nextScreen:
//            Image("custom.forward.rectangle")
//        case .previousScreen:
//            Image("custom.backward.rectangle")
//
//        case .larger:
//            Image(systemName: "plus.rectangle")
//        case .smaller:
//            Image(systemName: "minus.rectangle")
//
//        case .shrinkTop:
//            Image("custom.arrow.down.shrink.rectangle")
//        case .shrinkBottom:
//            Image("custom.arrow.up.shrink.rectangle")
//        case .shrinkRight:
//            Image("custom.arrow.left.shrink.rectangle")
//        case .shrinkLeft:
//            Image("custom.arrow.right.shrink.rectangle")
//
//        case .growTop:
//            Image("custom.arrow.up.grow.rectangle")
//        case .growBottom:
//            Image("custom.arrow.down.grow.rectangle")
//        case .growRight:
//            Image("custom.arrow.right.grow.rectangle")
//        case .growLeft:
//            Image("custom.arrow.left.grow.rectangle")
//
//        case .custom:
//            Image(systemName: "rectangle.dashed")
//        case .cycle:
//            Image("custom.arrow.2.squarepath.rectangle")
//        default:
//            nil
//        }
//    }
//
    var radialMenuImage: Image? {
        switch self.direction {
        case .hide:
            Image("custom.rectangle.slash")
        case .minimize:
            Image("custom.arrow.down.right.and.arrow.up.left.rectangle")
        default:
            nil
        }
    }
}
