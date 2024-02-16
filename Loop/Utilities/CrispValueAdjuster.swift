//
//  CrispValueAdjuster.swift
//  Loop
//
//  Created by Kai Azim on 2024-02-15.
//

import SwiftUI

// TODO: CHANGE NAME
struct CrispValueAdjuster<V>: View where V: Strideable, V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {

    let title: String
    let description: String?
    @Binding var value: V
    let postfix: String?

    @State var isPopoverShown: Bool = false

    init(_ title: String, description: String? = nil, value: Binding<V>, postfix: String? = nil) {
        self.title = title
        self.description = description
        self._value = value
        self.postfix = postfix
    }

    let stepperWidth: CGFloat = 150
    let stepperRange: ClosedRange<V> = 0...100

    var popoverXOffset: CGFloat {
        4 + ((stepperWidth - 8) * (CGFloat(value.clamped(to: stepperRange)) / CGFloat(stepperRange.upperBound)))
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)

                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack {
                stepperMinText

                Slider(
                    value: $value,
                    in: stepperRange,
                    step: V.Stride(stepperRange.upperBound / 10),
                    label: { EmptyView() },
                    onEditingChanged: { self.isPopoverShown = !$0 }
                )
                .labelsHidden()
                .frame(width: stepperWidth)
                .popover(
                    isPresented: $isPopoverShown,
                    attachmentAnchor: .rect(
                        .rect(
                            CGRect(
                                // This compensates for the small spacing within the slider
                                x: popoverXOffset,
                                y: 15,
                                width: 0,
                                height: 0
                            )
                        )
                    ),
                    arrowEdge: .bottom
                ) {
                    stepperView
                        .padding(10)
                        .fixedSize()
                }

                stepperMaxText
            }
            .fixedSize()
        }
    }

    @ViewBuilder
    var stepperView: some View {
        HStack {
            TextField("", value: $value, formatter: NumberFormatter())
                .labelsHidden()
                .textFieldStyle(.plain)
                .padding(4)
                .padding(.trailing, 12)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .foregroundStyle(.background)
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                .tertiary.opacity(0.5),
                                lineWidth: 1
                            )
                    }
                }
                .frame(minWidth: 20, maxWidth: 200)
                .overlay {
                    HStack {
                        Spacer()

                        Stepper("", value: $value, step: 10)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 1)
                }
                .fixedSize()
                .padding(.vertical, -10)

            if let postfix = postfix {
                Text(postfix)
            }
        }
    }

    @ViewBuilder
    var stepperMinText: some View {
        Text("\(stepperRange.lowerBound.formatted())\(postfix == nil ? "" : " \(postfix!)")")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.trailing, -4)
    }

    @ViewBuilder
    var stepperMaxText: some View {
        Text("\(stepperRange.upperBound.formatted())\(postfix == nil ? "" : " \(postfix!)")")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.leading, -4)
    }
}

extension Comparable {
    fileprivate func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
