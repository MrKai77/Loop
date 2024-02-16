//
//  CrispValueAdjuster.swift
//  Loop
//
//  Created by Kai Azim on 2024-02-15.
//

import SwiftUI

// TODO: CHANGE NAME
struct CrispValueAdjuster<V>: View where V: Strideable {

    let title: String
    let description: String?
    @Binding var value: V
    let postfix: String?

    init(_ title: String, description: String? = nil, value: Binding<V>, postfix: String? = nil) {
        self.title = title
        self.description = description
        self._value = value
        self.postfix = postfix
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

            if let postfix = postfix {
                Text(postfix)
            }
        }
    }
}

//#Preview {
//    CrispValueAdjuster()
//}
