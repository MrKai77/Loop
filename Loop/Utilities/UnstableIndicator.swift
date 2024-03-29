//
//  UnstableIndicator.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-02.
//

import SwiftUI

struct UnstableIndicator: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color) {
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
