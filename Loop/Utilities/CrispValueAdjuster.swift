//
//  CrispValueAdjuster.swift
//  Loop
//
//  Created by Kai Azim on 2024-02-15.
//

import SwiftUI

struct CrispValueAdjuster<V>: View where V: Strideable, V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {
    let title: String
    let description: String?
    @Binding var value: V
    let sliderRange: ClosedRange<V>
    let postscript: String?
    var step: V.Stride
    let upperClamp: Bool
    let lowerClamp: Bool

    @State var isPopoverShown: Bool = false

    init(
        _ title: String,
        description: String? = nil,
        value: Binding<V>,
        sliderRange: ClosedRange<V>,
        postscript: String? = nil,
        step: V? = nil,
        lowerClamp: Bool = false,
        upperClamp: Bool = false
    ) {
        self.title = title
        self.description = description
        self._value = value
        self.sliderRange = sliderRange
        self.postscript = postscript
        self.lowerClamp = lowerClamp
        self.upperClamp = upperClamp

        self.formatter = NumberFormatter()
        self.formatter.maximumFractionDigits = 10

        if let step = step {
            self.step = V.Stride(step)
        } else {
            self.step = 0   // Initialize first
            self.step = totalRange / 10
        }
    }

    let stepperWidth: CGFloat = 150
    let formatter: NumberFormatter

    var totalRange: V.Stride {
        V.Stride(sliderRange.upperBound) - V.Stride(sliderRange.lowerBound)
    }

    var popoverXOffset: CGFloat {
        4 + (stepperWidth - 8) * (
            CGFloat(
                value.clamped(to: sliderRange) - sliderRange.lowerBound
            ) / CGFloat(totalRange)
        )
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)

                Spacer()

                HStack {
                    stepperMinText

                    Slider(
                        value: $value,
                        in: sliderRange,
                        step: totalRange / 10,
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
                                    y: 0,
                                    width: 0,
                                    height: 0
                                )
                            )
                        ),
                        arrowEdge: .top
                    ) {
                        stepperView
                            .padding(10)
                            .fixedSize()
                    }

                    stepperMaxText
                }
                .fixedSize()
            }

            if let description = description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    var stepperView: some View {
        HStack {
            TextField(
                .init(""),
                value: Binding(
                    get: {
                        self.value
                    },
                    set: {
                        if lowerClamp && upperClamp {
                            self.value = $0.clamped(to: sliderRange)
                        } else if lowerClamp {
                            self.value = max(self.sliderRange.lowerBound, $0)
                        } else if upperClamp {
                            self.value = min(self.sliderRange.upperBound, $0)
                        } else {
                            self.value = $0
                        }
                    }
                ),
                formatter: formatter
            )
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
            .frame(minWidth: 20, maxWidth: 500)
            .overlay {
                HStack {
                    Spacer()

                    Stepper(
                        .init(""),
                        value: Binding(
                            get: {
                                self.value
                            },
                            set: {
                                if lowerClamp && upperClamp {
                                    self.value = $0.clamped(to: sliderRange)
                                } else if lowerClamp {
                                    self.value = max(self.sliderRange.lowerBound, $0)
                                } else if upperClamp {
                                    self.value = min(self.sliderRange.upperBound, $0)
                                } else {
                                    self.value = $0
                                }
                            }
                        ),
                        step: step
                    )
                    .labelsHidden()
                }
                .padding(.horizontal, 1)
            }
            .fixedSize()
            .padding(.vertical, -10)

            if let postfix = postscript {
                Text(postfix)
            }
        }
    }

    @ViewBuilder
    var stepperMinText: some View {
        Text("\(sliderRange.lowerBound.formatted())\(postscript == nil ? "" : " \(postscript!)")")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.trailing, -4)
    }

    @ViewBuilder
    var stepperMaxText: some View {
        Text("\(sliderRange.upperBound.formatted())\(postscript == nil ? "" : " \(postscript!)")")
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
