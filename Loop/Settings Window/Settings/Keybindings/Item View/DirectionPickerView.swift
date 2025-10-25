//
//  DirectionPickerView.swift
//  Loop
//
//  Created by Kai Azim on 2025-10-18.
//

import SwiftUI

struct DirectionPickerView: View {
    @Environment(\.luminarePopupPadding) private var luminarePopupPadding

    @State private var searchText = ""
    @State private var searchResults: [WindowDirection] = []

    @Binding private var direction: WindowDirection
    private let isInCycle: Bool

    private let sections: [PickerSection] = [
        .init(.init(localized: "General"), WindowDirection.general),
        .init(.init(localized: "Halves"), WindowDirection.halves),
        .init(.init(localized: "Quarters"), WindowDirection.quarters),
        .init(.init(localized: "Horizontal Thirds"), WindowDirection.horizontalThirds),
        .init(.init(localized: "Vertical Thirds"), WindowDirection.verticalThirds),
        .init(.init(localized: "Horizontal Fourths"), WindowDirection.horizontalFourths),
        .init(.init(localized: "Screen Switching"), WindowDirection.screenSwitching),
        .init(.init(localized: "Size Adjustment"), WindowDirection.sizeAdjustment),
        .init(.init(localized: "Shrink"), WindowDirection.shrink),
        .init(.init(localized: "Grow"), WindowDirection.grow),
        .init(.init(localized: "Move"), WindowDirection.move),
        .init(.init(localized: "Stash"), [WindowDirection.stash, WindowDirection.unstash]),
        .init(.init(localized: "Go Back"), [WindowDirection.initialFrame, WindowDirection.undo])
    ]

    private var moreSection: PickerSection<WindowDirection> {
        if isInCycle {
            .init(.init(localized: "More"), [WindowDirection.custom])
        } else {
            .init(.init(localized: "More"), [WindowDirection.custom, WindowDirection.cycle])
        }
    }

    private var sectionItems: [WindowDirection] {
        var result: [WindowDirection] = []

        for sectionItems in sections.map(\.items) {
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
                .padding(luminarePopupPadding)

            Divider()

            PickerList(
                $direction,
                $searchResults,
                sections + [moreSection]
            ) { item in
                HStack(spacing: 8) {
                    IconView(action: .init(item))
                        .equatable()

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
