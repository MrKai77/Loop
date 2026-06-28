//
//  GestureTrackpadPreview.swift
//  Loop
//
//  Created by Kai Azim on 2026-07-02.
//

import SwiftUI

struct GestureTrackpadPreview: View {
    let gesture: GestureBinding

    private let trackpadCornerRadius: CGFloat = 16
    private let trackpadInset: CGFloat = 13
    private let movementDistance: CGFloat = 30
    private let previewDuration = 1.9
    private let loopPauseDuration = 0.25
    private let radialMenuSegmentCount = 6

    var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { proxy in
                let rect = CGRect(origin: .zero, size: proxy.size)
                let usableRect = rect.insetBy(dx: trackpadInset, dy: trackpadInset)
                let sample = GesturePreviewSample(
                    kind: gesture.kind,
                    elapsedTime: elapsedTime(for: context.date),
                    previewDuration: previewDuration
                )
                let fingerRadius = 8.0
                let opacity = opacity(for: sample.localPhase)
                let progress = movementProgress(for: sample.localPhase)

                ZStack {
                    trackpadShape

                    ForEach(Array(fingerPositions(
                        in: usableRect,
                        sample: sample,
                        progress: progress,
                        fingerRadius: fingerRadius
                    ).enumerated()), id: \.offset) { _, point in
                        fingerDot(radius: fingerRadius)
                            .position(point)
                    }
                    .opacity(opacity)
                }
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fill)
        .accessibilityHidden(true)
    }

    private var trackpadShape: some View {
        RoundedRectangle(cornerRadius: trackpadCornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color(nsColor: .controlBackgroundColor).opacity(0.92),
                        Color(nsColor: .windowBackgroundColor).opacity(0.68)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: trackpadCornerRadius)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: trackpadCornerRadius - 4)
                    .strokeBorder(.black.opacity(0.2), lineWidth: 1)
                    .padding(3)
            }
            .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
    }

    private func fingerDot(radius: CGFloat) -> some View {
        Circle()
            .foregroundStyle(.tint.opacity(0.25))
            .background(.secondary, in: .circle)
            .frame(width: radius * 2, height: radius * 2)
    }

    private func fingerPositions(
        in rect: CGRect,
        sample: GesturePreviewSample,
        progress: CGFloat,
        fingerRadius: CGFloat
    ) -> [CGPoint] {
        FingerLayout.positions(count: gesture.fingerCount).map { normalizedPoint in
            let basePoint = point(from: normalizedPoint, in: rect)
            let animatedPoint = basePoint + sample.offset(
                for: normalizedPoint,
                progress: progress,
                distance: movementDistance
            )
            return clamp(animatedPoint, to: rect, padding: fingerRadius + 1)
        }
    }

    private func point(from normalizedPoint: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.midX + normalizedPoint.x * rect.width * 0.5,
            y: rect.midY + normalizedPoint.y * rect.height * 0.5
        )
    }

    private func clamp(_ point: CGPoint, to rect: CGRect, padding: CGFloat) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX + padding), rect.maxX - padding),
            y: min(max(point.y, rect.minY + padding), rect.maxY - padding)
        )
    }

    private func elapsedTime(for date: Date) -> TimeInterval {
        let activeDuration = gesture.kind == .radialMenu ? previewDuration * Double(radialMenuSegmentCount) : previewDuration
        let loopDuration = activeDuration + loopPauseDuration
        return date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: loopDuration)
    }

    private func opacity(for phase: CGFloat) -> CGFloat {
        let fadeInEnd = CGFloat(0.35 / 1.9)
        let moveEnd = CGFloat(1.2 / 1.9)
        let fadeOutEnd = CGFloat(1.45 / 1.9)

        if phase < fadeInEnd {
            return easeOut(phase / fadeInEnd)
        } else if phase < moveEnd {
            return 1
        } else if phase < fadeOutEnd {
            return 1 - easeInOut((phase - moveEnd) / (fadeOutEnd - moveEnd))
        } else {
            return 0
        }
    }

    private func movementProgress(for phase: CGFloat) -> CGFloat {
        let fadeInEnd = CGFloat(0.35 / 1.9)
        let moveEnd = CGFloat(1.2 / 1.9)

        guard phase >= fadeInEnd else { return 0 }
        guard phase < moveEnd else { return 1 }
        return easeInOut((phase - fadeInEnd) / (moveEnd - fadeInEnd))
    }

    private func easeOut(_ value: CGFloat) -> CGFloat {
        1 - pow(1 - min(max(value, 0), 1), 3)
    }

    private func easeInOut(_ value: CGFloat) -> CGFloat {
        let value = min(max(value, 0), 1)
        return value < 0.5
            ? 4 * value * value * value
            : 1 - pow(-2 * value + 2, 3) / 2
    }
}

private struct GesturePreviewSample {
    let kind: GestureBinding.Kind
    let localPhase: CGFloat

    init(kind: GestureBinding.Kind, elapsedTime: TimeInterval, previewDuration: TimeInterval) {
        if kind == .radialMenu {
            let radialMenuPreviewKinds: [GestureBinding.Kind] = [
                .pinch,
                .spread,
                .panUp,
                .panDown,
                .panLeft,
                .panRight
            ]
            let activeElapsedTime = min(elapsedTime, previewDuration * Double(radialMenuPreviewKinds.count))
            let segmentProgress = activeElapsedTime / previewDuration
            let segment = min(Int(segmentProgress), radialMenuPreviewKinds.count - 1)
            self.kind = radialMenuPreviewKinds[segment]
            self.localPhase = CGFloat(segmentProgress - Double(segment))
        } else {
            self.kind = kind
            self.localPhase = CGFloat(min(elapsedTime, previewDuration) / previewDuration)
        }
    }

    func offset(for normalizedPoint: CGPoint, progress: CGFloat, distance: CGFloat) -> CGSize {
        let pinchSpreadDistance = distance * 1.2

        return switch kind {
        case .radialMenu:
            CGSize(width: distance * progress, height: 0)
        case .panUp:
            CGSize(width: 0, height: -distance * progress)
        case .panDown:
            CGSize(width: 0, height: distance * progress)
        case .panLeft:
            CGSize(width: -distance * progress, height: 0)
        case .panRight:
            CGSize(width: distance * progress, height: 0)
        case .pinch:
            CGSize(
                width: -normalizedPoint.x * pinchSpreadDistance * progress,
                height: -normalizedPoint.y * pinchSpreadDistance * progress
            )
        case .spread:
            CGSize(
                width: normalizedPoint.x * pinchSpreadDistance * progress,
                height: normalizedPoint.y * pinchSpreadDistance * progress
            )
        }
    }
}

private enum FingerLayout {
    static func positions(count: Int) -> [CGPoint] {
        switch count {
        case 2:
            [
                CGPoint(x: -0.28, y: 0.34),
                CGPoint(x: 0.28, y: -0.34)
            ]
        case 3:
            [
                CGPoint(x: -0.42, y: 0.12),
                CGPoint(x: 0, y: -0.16),
                CGPoint(x: 0.42, y: 0.12)
            ]
        case 4:
            [
                CGPoint(x: -0.56, y: 0.18),
                CGPoint(x: -0.18, y: -0.18),
                CGPoint(x: 0.18, y: -0.12),
                CGPoint(x: 0.56, y: 0.22)
            ]
        case 5:
            [
                CGPoint(x: -0.68, y: 0.42),
                CGPoint(x: -0.46, y: 0.08),
                CGPoint(x: -0.14, y: -0.20),
                CGPoint(x: 0.22, y: -0.12),
                CGPoint(x: 0.58, y: 0.22)
            ]
        default:
            []
        }
    }
}

private func + (point: CGPoint, size: CGSize) -> CGPoint {
    CGPoint(x: point.x + size.width, y: point.y + size.height)
}
