//
//  WindowAction+Image.swift
//  Loop
//
//  Created by phlpsong on 2024/3/30.
//

import Luminare
import SwiftUI

extension WindowAction {
    var image: NSImage? {
        switch direction {
        case .undo:
            NSImage(systemSymbolName: "arrow.uturn.backward", accessibilityDescription: nil)
        case .initialFrame:
            NSImage(systemSymbolName: "backward.end.alt.fill", accessibilityDescription: nil)
        case .hide:
            NSImage(systemSymbolName: "eye.slash.fill", accessibilityDescription: nil)
        case .minimize:
            NSImage(systemSymbolName: "arrow.down.right.and.arrow.up.left", accessibilityDescription: nil)
        case .minimizeOthers:
            NSImage(systemSymbolName: "arrow.down.right.and.arrow.up.left", accessibilityDescription: nil)
        case .maximizeHeight:
            NSImage(systemSymbolName: "arrow.up.and.down", accessibilityDescription: nil)
        case .maximizeWidth:
            NSImage(systemSymbolName: "arrow.left.and.right", accessibilityDescription: nil)
        case .nextScreen:
            NSImage(systemSymbolName: "forward.fill", accessibilityDescription: nil)
        case .previousScreen:
            NSImage(systemSymbolName: "backward.fill", accessibilityDescription: nil)
        case .leftScreen:
            NSImage(systemSymbolName: "arrow.left.to.line", accessibilityDescription: nil)
        case .rightScreen:
            NSImage(systemSymbolName: "arrow.right.to.line", accessibilityDescription: nil)
        case .topScreen:
            NSImage(systemSymbolName: "arrow.up.to.line", accessibilityDescription: nil)
        case .bottomScreen:
            NSImage(systemSymbolName: "arrow.down.to.line", accessibilityDescription: nil)
        case .larger:
            NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: nil)
        case .smaller:
            NSImage(systemSymbolName: "arrow.down.right.and.arrow.up.left", accessibilityDescription: nil)
        case .shrinkTop, .growBottom, .moveDown:
            NSImage(systemSymbolName: "arrow.down", accessibilityDescription: nil)
        case .shrinkBottom, .growTop, .moveUp:
            NSImage(systemSymbolName: "arrow.up", accessibilityDescription: nil)
        case .shrinkRight, .growLeft, .moveLeft:
            NSImage(systemSymbolName: "arrow.left", accessibilityDescription: nil)
        case .shrinkLeft, .growRight, .moveRight:
            NSImage(systemSymbolName: "arrow.right", accessibilityDescription: nil)
        case .shrinkHorizontal:
            NSImage(systemSymbolName: "arrow.right.and.line.vertical.and.arrow.left", accessibilityDescription: nil)
        case .growHorizontal:
            NSImage(systemSymbolName: "arrow.left.and.line.vertical.and.arrow.right", accessibilityDescription: nil)
        case .shrinkVertical:
            NSImage(systemSymbolName: "arrow.down.and.line.horizontal.and.arrow.up", accessibilityDescription: nil)
        case .growVertical:
            NSImage(systemSymbolName: "arrow.up.and.line.horizontal.and.arrow.down", accessibilityDescription: nil)
        case .focusLeft:
            NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil)
        case .focusRight:
            NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        case .focusUp:
            NSImage(systemSymbolName: "chevron.up", accessibilityDescription: nil)
        case .focusDown:
            NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)
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
struct IconView: NSViewRepresentable {
    private let action: WindowAction
    private let size: CGSize

    init(
        action: WindowAction,
        size: CGSize = .init(
            width: 18,
            height: 14
        )
    ) {
        self.action = action
        self.size = size
    }

    func makeNSView(context _: Context) -> IconRenderView {
        let view = IconRenderView()

        if action.direction == .cycle, let first = action.cycle?.first {
            view.setAction(to: first, animated: false)
        } else {
            view.setAction(to: action, animated: false)
        }

        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: size.width),
            view.heightAnchor.constraint(equalToConstant: size.height)
        ])

        return view
    }

    func updateNSView(_ view: IconRenderView, context _: Context) {
        if action.direction == .cycle, let first = action.cycle?.first {
            view.setAction(to: first, animated: true)
        } else {
            view.setAction(to: action, animated: true)
        }
    }
}

final class IconRenderView: NSView {
    private var currentAction: WindowAction = .init(.noAction)
    private var lastDisplayMode: DisplayMode?

    private let strokeLayer = CAShapeLayer()
    private let fillLayer = CAShapeLayer()
    private let imageLayer = CALayer()

    private let cornerRadius: CGFloat = 3
    private let inset: CGFloat = 2
    private let strokeWidth: CGFloat = 1.5

    enum DisplayMode {
        case frame(CGRect)
        case image(NSImage)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func setAction(
        to action: WindowAction,
        animated: Bool
    ) {
        guard !action.isSameManipulation(as: currentAction) else { return }
        currentAction = action
        updatePath(duration: animated ? 0.2 : 0.0)
    }

    override func layout() {
        super.layout()
        updatePath(duration: 0.0)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    // MARK: - Private

    private func setup() {
        wantsLayer = true
        clipsToBounds = true

        layer?.addSublayer(strokeLayer)
        layer?.addSublayer(fillLayer)
        layer?.addSublayer(imageLayer)

        strokeLayer.lineWidth = 1
        strokeLayer.cornerCurve = .continuous
        fillLayer.cornerCurve = .continuous
        imageLayer.contentsGravity = .resizeAspect

        updateColors()
    }

    private func updateColors() {
        strokeLayer.fillColor = .clear
        strokeLayer.strokeColor = NSColor.textColor.cgColor
        fillLayer.fillColor = NSColor.textColor.cgColor

        if case let .image(image) = lastDisplayMode {
            imageLayer.contents = processImage(image, color: .textColor)
        }
    }

    private func updatePath(duration: CFTimeInterval) {
        strokeLayer.frame = bounds
        fillLayer.frame = bounds

        let strokeInset = strokeWidth / 2
        processStrokeLayerPath(strokeInset: strokeInset)

        let fillInset = strokeInset + inset
        let fillBounds = bounds.insetBy(dx: fillInset, dy: fillInset)

        guard let displayMode = determineDisplayMode(fillBounds: fillBounds) else {
            fillLayer.opacity = 0
            imageLayer.opacity = 0
            return
        }

        switch displayMode {
        case let .frame(fillRect):
            let newPath = CGPath(
                roundedRect: fillRect,
                cornerWidth: cornerRadius - inset,
                cornerHeight: cornerRadius - inset,
                transform: nil
            )
            animateAlpha(layer: fillLayer, to: 1, duration: duration)
            animateAlpha(layer: imageLayer, to: 0, duration: duration)
            animatePath(layer: fillLayer, to: newPath, duration: duration)
        case let .image(image):
            imageLayer.contents = processImage(image, color: .textColor)
            imageLayer.frame = getImageBounds()
            animateAlpha(layer: fillLayer, to: 0, duration: duration)
            animateAlpha(layer: imageLayer, to: 1, duration: duration)
        }

        lastDisplayMode = displayMode
    }

    private func processStrokeLayerPath(strokeInset: CGFloat) {
        let strokeRect = bounds.insetBy(dx: strokeInset, dy: strokeInset)
        let strokePath = CGPath(
            roundedRect: strokeRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        strokeLayer.path = strokePath
    }

    private func determineDisplayMode(fillBounds: CGRect) -> DisplayMode? {
        if let image = currentAction.image {
            return .image(image)
        }

        let frame = currentAction.getFrame(
            window: nil,
            bounds: .init(origin: .zero, size: .init(width: 1, height: 1)),
            disablePadding: true
        ).flipY(maxY: 1)

        if frame.size.area != 0 {
            let fillFrame = CGRect(
                x: fillBounds.minX + fillBounds.width * frame.minX,
                y: fillBounds.minY + fillBounds.height * frame.minY,
                width: fillBounds.width * frame.width,
                height: fillBounds.height * frame.height
            )

            return .frame(fillFrame)
        }

        // And if all else fails...

        if currentAction.direction == .custom, let image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil) {
            return .image(image)
        }

        if currentAction.direction == .cycle, let image = NSImage(systemSymbolName: "repeat", accessibilityDescription: nil) {
            return .image(image)
        }

        return nil
    }

    private func animatePath(
        layer: CAShapeLayer,
        to target: CGPath,
        duration: CFTimeInterval
    ) {
        if duration > 0 {
            let animation = CABasicAnimation(keyPath: "path")
            animation.fromValue = layer.path
            animation.toValue = target
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(animation, forKey: "path")
        }

        layer.path = target
    }

    private func animateAlpha(
        layer: CALayer,
        to target: Float,
        duration: CFTimeInterval
    ) {
        if duration > 0 {
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = layer.opacity
            animation.toValue = target
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(animation, forKey: "opacity")
        }

        layer.opacity = target
    }

    private func processImage(_ image: NSImage, color: NSColor) -> NSImage? {
        guard image.isTemplate else { return image }
        let image = image.withSymbolConfiguration(.init(pointSize: 12, weight: .bold)) ?? image

        let sizedImage = NSImage(size: image.size)
        sizedImage.lockFocus()
        defer { sizedImage.unlockFocus() }

        image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        color.setFill()
        let rect = NSRect(origin: .zero, size: image.size)
        rect.fill(using: .sourceIn)

        return sizedImage
    }

    private func getImageBounds() -> NSRect {
        let insetBounds = bounds.insetBy(dx: strokeWidth, dy: strokeWidth)
        let side = min(insetBounds.width, insetBounds.height)
        let squareRect = CGRect(
            x: insetBounds.midX - side / 2,
            y: insetBounds.midY - side / 2,
            width: side,
            height: side
        )
        return squareRect
    }
}
