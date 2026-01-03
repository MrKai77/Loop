//
//  RadialMenuActionPickerView.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-02.
//

import Defaults
import SwiftUI

struct RadialMenuActionPickerView: View {
    @Default(.keybinds) private var keybinds

    private let padding: CGFloat = 12

    @State private var searchText = ""
    @State private var searchResults: [RadialMenuAction.ActionType] = []

    @Binding private var selection: RadialMenuAction.ActionType

    private static let directionSections: [PickerSection<RadialMenuAction.ActionType>] = {
        let windowDirections = PickerSection.windowDirections
            .map { section in
                PickerSection(
                    section.title,
                    section.items.map { RadialMenuAction.ActionType.custom(.init($0)) }
                )
            }

        let moreSection = PickerSection(
            String(localized: "More", comment: "Section header in the action picker of the Keybinds tab"),
            [WindowDirection.custom, WindowDirection.cycle].map { RadialMenuAction.ActionType.custom(.init($0)) }
        )

        return windowDirections + [moreSection]
    }()

    private var keybindsSection: PickerSection<RadialMenuAction.ActionType> {
        PickerSection(
            "Your Keybinds",
            keybinds.map { RadialMenuAction.ActionType.keybindReference($0.id) }
        )
    }

    private var allSections: [PickerSection<RadialMenuAction.ActionType>] {
        Self.directionSections + [keybindsSection]
    }

    private var allSectionItems: [RadialMenuAction.ActionType] {
        allSections
            .map(\.items)
            .flatMap(\.self)
    }

    init(selection: Binding<RadialMenuAction.ActionType>) {
        self._selection = selection
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
                $selection,
                $searchResults,
                padding,
                allSections
            ) { item in
                HStack(spacing: 8) {
                    if let action = item.resolvedAction {
                        HStack(spacing: 8) {
                            IconView(action: action)

                            Text(action.getName())
                                .fontWeight(.regular)
                                .lineLimit(1)
                        }
                    } else {
                        Image(systemName: "bolt.horizontal.fill")
                    }

                    Spacer()

                    if item.isKeybindReference {
                        Image(systemName: "keyboard")
                            .foregroundStyle(.secondary)
                    }
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

        let matches = allSectionItems
            .compactMap { item -> (RadialMenuAction.ActionType, Int)? in
                guard let action = item.resolvedAction else { return nil }

                if let score = fuzzyScore(action.getName(), key) {
                    return (item, score)
                }

                return nil
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)

        searchResults = matches
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
