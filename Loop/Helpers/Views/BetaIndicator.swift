//
//  BetaIndicator.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-02.
//

import SwiftUI

struct BetaIndicator: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = .green) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background {
                RoundedRectangle(cornerRadius: 50)
                    .stroke(lineWidth: 1)
            }
            .foregroundStyle(color)
    }
}
