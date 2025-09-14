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
        case .undo:
            Image(systemName: "arrow.uturn.backward")
        case .initialFrame:
            Image(systemName: "backward.end.alt.fill")
        case .hide:
            Image(systemName: "eye.slash.fill")
        case .minimize:
            Image(systemName: "arrow.down.right.and.arrow.up.left")
        case .minimizeOthers:
            Image(systemName: "arrow.down.right.and.arrow.up.left")
        case .maximizeHeight:
            Image(systemName: "arrow.up.and.down")
        case .maximizeWidth:
            Image(systemName: "arrow.left.and.right")
        case .nextScreen:
            Image(systemName: "forward.fill")
        case .previousScreen:
            Image(systemName: "backward.fill")
        case .leftScreen:
            Image(systemName: "arrow.left.to.line")
        case .rightScreen:
            Image(systemName: "arrow.right.to.line")
        case .topScreen:
            Image(systemName: "arrow.up.to.line")
        case .bottomScreen:
            Image(systemName: "arrow.down.to.line")
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
        case .shrinkHorizontal:
            Image(systemName: "arrow.right.and.line.vertical.and.arrow.left")
        case .growHorizontal:
            Image(systemName: "arrow.left.and.line.vertical.and.arrow.right")
        case .shrinkVertical:
            Image(systemName: "arrow.down.and.line.horizontal.and.arrow.up")
        case .growVertical:
            Image(systemName: "arrow.up.and.line.horizontal.and.arrow.down")
        default:
            nil
        }
    }

    var radialMenuImage: Image? {
        switch direction {
        case .hide:
            Image(systemName: "eye.slash")
        case .minimize:
            Image(systemName: "arrow.down.right.and.arrow.up.left")
        case .minimizeOthers:
            Image(systemName: "arrow.down.right.and.arrow.up.left")
        default:
            nil
        }
    }
}

/// An icon to represent a `WindowAction`.
/// When the action is a cycle, it will display the first action in the cycle.
/// Icons will prioritize using the action's `icon` property, then a simple frame preview, and finally a default icon.
/// - the `icon` property is used for common actions like hide, minimize, growing and shrinking, which cannot be easily represented by a frame.
/// - a simple frame preview is used for more general actions such as right half, maximize, and center, as well as custom keybinds when available.
/// - finally, a default icon is used for cycle actions and actions without a specific icon or frame representation as backup (just in case, they shouldn't be needed in practice).
///
/// It is also important to note that this view conforms to `Equatable` to prevent accidental re-renders when used in lists or other dynamic views.
/// Please ensure that the `.equatable()` modifier is applied when using this view in such contexts.
struct IconView: View, Equatable {
    @Environment(\.luminareAnimationFast) private var luminareAnimationFast

    private let action: WindowAction
    private let size = CGSize(width: 14, height: 10)
    private let inset: CGFloat = 2
    private let outerCornerRadius: CGFloat = 3
    private var frame: CGRect {
        action.getFrame(
            window: nil,
            bounds: .init(origin: .zero, size: size),
            disablePadding: true
        )
    }

    /// Creates an icon view for a given window action.
    /// - Parameter action: The window action to represent.
    init(action: WindowAction) {
        self.action = action
    }

    var body: some View {
        if action.direction == .cycle, let first = action.cycle?.first {
            IconView(action: first)
                .id(first.id)
                .animation(luminareAnimationFast, value: first)
        } else {
            Group {
                if let icon = action.icon {
                    icon
                        .font(.system(size: 8))
                        .fontWeight(.bold)
                        .frame(width: size.width, height: size.height, alignment: .center)
                } else if frame.size.area != 0 {
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
                } else if action.direction == .cycle {
                    Image(.repeat4)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height, alignment: .center)
                } else {
                    Image(.ruler)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height, alignment: .center)
                }
            }
            .clipShape(.rect(cornerRadius: outerCornerRadius - inset))
            .background {
                RoundedRectangle(cornerRadius: outerCornerRadius)
                    .stroke(lineWidth: 1)
                    .padding(-inset)
            }
            .padding(.horizontal, 4)
        }
    }

    static func == (lhs: IconView, rhs: IconView) -> Bool {
        lhs.action == rhs.action
    }
}
