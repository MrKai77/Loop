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
                            isPreview: true
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
                            isPreview: false
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
