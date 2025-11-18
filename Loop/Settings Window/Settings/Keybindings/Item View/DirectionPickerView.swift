//
//  DirectionPickerView.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-18.
//

import SwiftUI

struct DirectionPickerView: View {
    private let padding: CGFloat = 12

    @State private var searchText = ""
    @State private var searchResults: [WindowDirection] = []

    @Binding private var direction: WindowDirection
    private let isInCycle: Bool

    private static let sections: [PickerSection] = [
        .init(String(localized: "General", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.general),
        .init(String(localized: "Halves", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.halves),
        .init(String(localized: "Quarters", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.quarters),
        .init(String(localized: "Horizontal Thirds", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.horizontalThirds),
        .init(String(localized: "Vertical Thirds", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.verticalThirds),
        .init(String(localized: "Horizontal Fourths", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.horizontalFourths),
        .init(String(localized: "Screen Switching", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.screenSwitching),
        .init(String(localized: "Size Adjustment", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.sizeAdjustment),
        .init(String(localized: "Shrink", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.shrink),
        .init(String(localized: "Grow", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.grow),
        .init(String(localized: "Move", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.move),
        .init(String(localized: "Focus", comment: "Section header in the action picker of the Keybinds tab"), WindowDirection.focus),
        .init(String(localized: "Stash", comment: "Section header in the action picker of the Keybinds tab"), [WindowDirection.stash, WindowDirection.unstash]),
        .init(String(localized: "Go Back", comment: "Section header in the action picker of the Keybinds tab"), [WindowDirection.initialFrame, WindowDirection.undo])
    ]

    private var moreSection: PickerSection<WindowDirection> {
        let title = String(localized: "More", comment: "Section header in the action picker of the Keybinds tab")
        if isInCycle {
            return .init(title, [WindowDirection.custom])
        } else {
            return .init(title, [WindowDirection.custom, WindowDirection.cycle])
        }
    }

    private var sectionItems: [WindowDirection] {
        var result: [WindowDirection] = []

        for sectionItems in Self.sections.map(\.items) {
            result.append(contentsOf: sectionItems)
        }

        return result
    }

    init(direction: Binding<WindowDirection>, isInCycle: Bool) {
        self._direction = direction
        self.isInCycle = isInCycle
    }

    var body: some View {
        VStack(spacing: 0) {
            CustomTextField($searchText)
                .padding(padding)

            Divider()

            PickerList(
                $direction,
                $searchResults,
                padding,
                Self.sections + [moreSection]
            ) { item in
                HStack(spacing: 8) {
                    IconView(action: .init(item))

                    Text(item.name)
                }
                .compositingGroup()
            }
        }
        .frame(width: 300, height: 300)
        .onAppear {
            searchText = ""
            computeSearchResults()
        }
        .onDisappear {
            searchText = ""
        }
        .onChange(of: searchText) { _ in
            computeSearchResults()
        }
    }

    private func computeSearchResults() {
        withAnimation {
            if searchText.isEmpty {
                searchResults = []
            } else {
                searchResults = sectionItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) } + moreSection.items
            }
        }
    }
}
