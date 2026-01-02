//
//  RadialMenuActionItemView.swift
//  Loop
//
//  Created by Kai Azim on 2025-12-08.
//

import Defaults
import Luminare
import SwiftUI

struct RadialMenuActionItemView: View {
    @EnvironmentObject private var windowModel: SettingsWindowManager
    @Environment(\.luminareItemBeingHovered) private var isHovering
    @Environment(\.luminareAnimation) var luminareAnimation
    @Default(.radialMenuActions) private var radialMenuActions
    @Default(.keybinds) private var keybinds

    @Binding private var radialMenuAction: RadialMenuWindowAction

    @State private var isPickerPresented = false
    @State private var isConfiguringCustom: Bool = false
    @State private var isConfiguringCycle: Bool = false

    init(_ action: Binding<RadialMenuWindowAction>) {
        self._radialMenuAction = action
    }

    var body: some View {
        HStack {
            label
            
            Spacer()

            if radialMenuAction.isKeybindReference {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .onChange(of: isHovering) { _ in
            if !isHovering {
                isPickerPresented = false
            }
        }
        .onChange(of: radialMenuAction.resolvedAction) { _ in
            if let resolvedAction = radialMenuAction.resolvedAction {
                if resolvedAction.direction.isCustomizable {
                    isConfiguringCustom = true
                }
                if resolvedAction.direction == .cycle {
                    isConfiguringCycle = true
                }
            }
        }
    }

    @ViewBuilder
    private var label: some View {
        actionIndicator
            .background {
                if isHovering {
                    Color.clear
                        .luminarePopup(
                            isPresented: $isPickerPresented,
                            alignment: .leadingLastTextBaseline
                        ) {
                            RadialMenuActionPickerView(selection: $radialMenuAction)
                        }
                        .luminareSheetClosesOnDefocus(true)
                }
            }
    }

    @ViewBuilder
    var actionIndicator: some View {
        HStack(spacing: 2) {
            Button {
                isPickerPresented = true
            } label: {
                HStack(spacing: 8) {
                    if let action = radialMenuAction.resolvedAction {
                        IconView(action: action)

                        Text(action.getName())
                            .fontWeight(.regular)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "bolt.horizontal.fill")
                            .foregroundStyle(.secondary)

                        Text("Failed to resolve keybind")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .luminareContentSize(contentMode: .fit, hasFixedHeight: true)
            .luminareRoundingBehavior(top: true, bottom: true)
            .luminareFilledStates([.hovering, .pressed])
            .luminareBorderedStates(.hovering)
            .luminareMinHeight(24)
            .padding(.leading, -4)

            Group {
                if let resolvedAction = radialMenuAction.resolvedAction {
                    let actionBinding = Binding<WindowAction>(
                        get: {
                            resolvedAction
                        },
                        set: { newAction in
                            if radialMenuAction.isKeybindReference {
                                guard let index = radialMenuAction.keybindIndex else {
                                    return
                                }

                                keybinds[index] = newAction
                            } else {
                                radialMenuAction = .custom(newAction)
                            }
                        }
                    )

                    if resolvedAction.direction.isCustomizable {
                        Button(action: {
                            isConfiguringCustom = true
                        }, label: {
                            Image(systemName: "slider.horizontal.3")
                        })
                        .buttonStyle(.plain)
                        .luminareModalWithPredefinedSheetStyle(isPresented: $isConfiguringCustom, isCompact: false) {
                            if resolvedAction.direction == .custom {
                                CustomActionConfigurationView(action: actionBinding, isPresented: $isConfiguringCustom)
                                    .frame(width: 400)
                            } else {
                                StashActionConfigurationView(action: actionBinding, isPresented: $isConfiguringCustom)
                                    .frame(width: 400)
                            }
                        }
                        .help("Customize this keybind's custom frame.")
                    }

                    if resolvedAction.direction == .cycle {
                        Button(action: {
                            isConfiguringCycle = true
                        }, label: {
                            Image(systemName: "repeat")
                        })
                        .buttonStyle(.plain)
                        .luminareModalWithPredefinedSheetStyle(isPresented: $isConfiguringCycle, isCompact: false) {
                            CycleActionConfigurationView(action: actionBinding, isPresented: $isConfiguringCycle)
                                .frame(width: 400)
                        }
                        .help("Customize what this action cycles through.")
                    }
                }
            }
            .font(.title3)
            .foregroundStyle(isHovering ? .primary : .secondary)
        }
    }
}

struct RadialMenuActionPickerView: View {
    @Default(.keybinds) private var keybinds

    private let padding: CGFloat = 12

    @State private var searchText = ""
    @State private var searchResults: [RadialMenuWindowAction] = []

    @Binding private var selection: RadialMenuWindowAction

    private static let directionSections: [PickerSection<RadialMenuWindowAction>] = {
        let windowDirections = PickerSection.windowDirections
            .map { section in
                PickerSection(
                    section.title,
                    section.items.map { RadialMenuWindowAction.custom(.init($0)) }
                )
            }

        return windowDirections
    }()

    private var keybindsSection: PickerSection<RadialMenuWindowAction> {
        PickerSection(
            "Your Keybinds",
            keybinds.map { RadialMenuWindowAction.keybindReference($0.id) }
        )
    }

    private var allSections: [PickerSection<RadialMenuWindowAction>] {
        Self.directionSections + [keybindsSection]
    }

    private var allSectionItems: [RadialMenuWindowAction] {
        allSections
            .map(\.items)
            .flatMap(\.self)
    }

    init(selection: Binding<RadialMenuWindowAction>) {
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
                        Image(systemName: "link")
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
            .compactMap { item -> (RadialMenuWindowAction, Int)? in
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
