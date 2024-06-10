//
//  MenuBarHeaderText.swift
//  Loop
//
//  Created by Kai Azim on 2023-09-30.
//

import SwiftUI

struct MenuBarHeaderText: View {
    var label: String

    init(_ label: String) {
        self.label = label
    }

    public var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
    }
}
