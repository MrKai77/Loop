//
//  WindowAction+Image.swift
//  Loop
//
//  Created by phlpsong on 2024/3/30.
//

import Luminare
import SwiftUI

extension WindowAction {
    var icon: Image? {
        switch direction {
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
        case .shrinkTop, .growBottom, .moveDown:
            Image(systemName: "arrow.down")
        case .shrinkBottom, .growTop, .moveUp:
            Image(systemName: "arrow.up")
        case .shrinkRight, .growLeft, .moveLeft:
            Image(systemName: "arrow.left")
        case .shrinkLeft, .growRight, .moveRight:
            Image(systemName: "arrow.right")
        default:
            nil
        }
    }

    var radialMenuImage: Image? {
        switch direction {
        case .hide:
            Image("custom.rectangle.slash")
        case .minimize:
            Image("custom.arrow.down.right.and.arrow.up.left.rectangle")
        default:
            nil
        }
    }
}

struct IconView: View {
    @Binding var action: WindowAction
    @State var frame: CGRect = .init(x: 0, y: 0, width: 1, height: 1)

    let size = CGSize(width: 14, height: 10)
    let inset: CGFloat = 2
    let outerCornerRadius: CGFloat = 3

    var body: some View {
        if action.direction == .cycle, let first = action.cycle?.first {
            IconView(action: .constant(first))
        } else {
            ZStack {
                if let icon = action.icon {
                    icon
                        .font(.system(size: 8))
                        .fontWeight(.bold)
                        .frame(width: size.width, height: size.height)
                } else if action.direction == .cycle, action.cycle?.first == nil {
                    Image(._18PxRepeat4)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size.width, height: size.height)
                } else if action.direction == .custom, frame == .zero {
                    Image(._18PxSliders)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size.width, height: size.height)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: outerCornerRadius - inset)
                            .frame(
                                width: frame.width,
                                height: frame.height
                            )
                            .offset(
                                x: frame.origin.x,
                                y: frame.origin.y
                            )
                    }
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .onAppear {
                        refreshFrame()
                    }
                    .onChange(of: action) { _ in
                        withAnimation(LuminareSettingsWindow.fastAnimation) {
                            refreshFrame()
                        }
                    }
                }
            }
            .clipShape(.rect(cornerRadius: outerCornerRadius - inset))
            .background {
                RoundedRectangle(cornerRadius: outerCornerRadius)
                    .stroke(lineWidth: 1.5)
                    .padding(-inset)
            }
            .padding(.horizontal, 4)
        }
    }

    func refreshFrame() {
        frame = action.getFrame(window: nil, bounds: .init(origin: .zero, size: size), disablePadding: true)
    }
}
