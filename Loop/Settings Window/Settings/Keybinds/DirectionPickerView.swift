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

    private var sections: [PickerSection<WindowDirection>] {
        PickerSection.windowDirections
    }

    private var moreSection: PickerSection<WindowDirection> {
        let title = String(localized: "More", comment: "Section header in the action picker of the Keybinds tab")
        if isInCycle {
            return .init(title, [WindowDirection.custom])
        } else {
            return .init(title, [WindowDirection.custom, WindowDirection.cycle])
        }
    }

    private var sectionItems: [WindowDirection] {
        sections
            .map(\.items)
            .flatMap(\.self)
    }

    init(direction: Binding<WindowDirection>, isInCycle: Bool) {
        self._direction = direction
        self.isInCycle = isInCycle
    }

    var body: some View {
        VStack(spacing: 0) {
            CustomTextField(
                $searchText,
                placeholder: .init(localized: "Search for a window action", defaultValue: "Search…")
            )
            .padding(padding)

            Divider()

            PickerList(
                $direction,
                $searchResults,
                padding,
                sections + [moreSection]
            ) { item in
                HStack(spacing: 8) {
                    IconView(action: .init(item))

                    Text(item.name)
                }
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
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        let key = searchText.lowercased()

        let matches = sectionItems
            .compactMap { item -> (WindowDirection, Int)? in
                if let score = fuzzyScore(item.name, key) {
                    return (item, score)
                }
                return nil
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)

        searchResults = matches + moreSection.items
    }

    private func fuzzyScore(_ text: String, _ pattern: String) -> Int? {
        let text = text.lowercased()
        let pattern = pattern.lowercased()

        // Strong prefix match
        if text.hasPrefix(pattern) { return 0 }

        // Contains substring
        if text.contains(pattern) { return 1 }

        // Subsequence fuzzy match (letters appear in order)
        var tIndex = text.startIndex
        var pIndex = pattern.startIndex
        while tIndex < text.endIndex, pIndex < pattern.endIndex {
            if text[tIndex] == pattern[pIndex] {
                pIndex = text.index(after: pIndex)
            }
            tIndex = text.index(after: tIndex)
        }

        if pIndex == pattern.endIndex { return 2 }

        return nil
    }
}
