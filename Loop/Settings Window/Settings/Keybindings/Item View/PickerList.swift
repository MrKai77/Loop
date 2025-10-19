//
//  PickerList.swift
//  Loop
//
//  Created by Kai Azim on 2024-08-25.
//

import Luminare
import OSLog
import SwiftUI

struct PickerList<Content, V>: View where Content: View, V: Hashable, V: Identifiable {
    @EnvironmentObject private var popover: LuminarePopupPanel
    @Environment(\.luminarePopupPadding) private var luminarePopupPadding

    private let logger = Logger(category: "PickerView")

    @Binding var selection: V
    @Binding var searchResults: [V]

    @State private var arrowSelection: V?
    @State private var eventMonitor: LocalEventMonitor?
    @State private var isInitialRender = true

    private let sections: [PickerSection<V>]
    private let content: (V) -> Content

    init(
        _ selection: Binding<V>,
        _ searchResults: Binding<[V]>,
        _ sections: [PickerSection<V>],
        @ViewBuilder content: @escaping (V) -> Content
    ) {
        self._selection = selection
        self._searchResults = searchResults
        self.sections = sections
        self.content = content
    }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: luminarePopupPadding) {
                    contentStack(reader: reader)
                }
                .padding(luminarePopupPadding / 2)
            }
        }
    }

    @ViewBuilder
    private func contentStack(reader: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if searchResults.isEmpty {
                sectionsView
            } else {
                searchResultsView
            }
        }
        .onChange(of: searchResults) { _ in arrowSelection = nil }
        .onAppear {
            Task { @MainActor in
                setupEventMonitor(reader: reader)
                eventMonitor?.start()
                isInitialRender = false
            }
        }
        .onDisappear {
            logger.info("Stopping event monitor")
            eventMonitor?.stop()
            eventMonitor = nil
        }
    }

    private var sectionsView: some View {
        ForEach(sections.prefix(isInitialRender ? 1 : sections.count)) { section in
            Section {
                ForEach(section.items, id: \.self) { item in
                    PopoverPickerItem(
                        selection: $selection,
                        arrowSelection: arrowSelection,
                        item: item,
                        content: content
                    )
                    .id(item)
                }
            } header: {
                Text(section.title)
                    .foregroundStyle(.secondary)
                    .padding(.leading, luminarePopupPadding / 2)
                    .padding(.top, luminarePopupPadding / 2)
            }
        }
    }

    private var searchResultsView: some View {
        ForEach(searchResults) { item in
            PopoverPickerItem(
                selection: $selection,
                arrowSelection: arrowSelection,
                item: item,
                content: content
            )
            .id(item)
        }
    }

    private func setupEventMonitor(reader: ScrollViewProxy) {
        eventMonitor = LocalEventMonitor(events: [.keyDown]) { event in
            switch event.keyCode {
            case .kVK_DownArrow:
                updateArrowSelection(increment: true, reader: reader)
            case .kVK_UpArrow:
                updateArrowSelection(increment: false, reader: reader)
            case .kVK_Return:
                if let arrowSelection {
                    selection = arrowSelection
                    popover.close()
                }
            case .kVK_Escape:
                popover.close()
            default:
                return event
            }
            return nil
        }
    }

    private func updateArrowSelection(increment: Bool, reader: ScrollViewProxy) {
        let items = searchResults.isEmpty ? sections.flatMap(\.items) : searchResults
        guard !items.isEmpty else { return }

        let currentIndex = items.firstIndex(where: { $0 == arrowSelection }) ?? (increment ? -1 : items.count)
        let nextIndex = currentIndex + (increment ? 1 : -1)

        /// Ensure nextIndex is valid
        guard nextIndex >= 0, nextIndex < items.count else {
            logger.error("Invalid nextIndex: \(nextIndex), items count: \(items.count)")
            return
        }

        let newSelection = items[nextIndex]
        arrowSelection = newSelection

        /// Only scroll if the selection is valid and not nil
        guard let validSelection = arrowSelection else {
            logger.info("arrowSelection is nil, skipping scroll")
            return
        }

        reader.scrollTo(validSelection, anchor: .center)
    }
}

struct PopoverPickerItem<Content, V>: View where Content: View, V: Hashable {
    @EnvironmentObject private var popover: LuminarePopupPanel
    @Environment(\.luminarePopupPadding) private var luminarePopupPadding
    @Environment(\.luminareAnimationFast) private var animationFast

    @State private var isHovering = false
    @Binding var selection: V
    let arrowSelection: V?
    let item: V
    let content: (V) -> Content

    private var isActive: Bool {
        selection == item
    }

    private var isSelected: Bool {
        isHovering || arrowSelection == item
    }

    var body: some View {
        Button {
            selection = item
            popover.resignKey()
        } label: {
            content(item)
                .padding(luminarePopupPadding / 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(
            SearchablePickerButtonStyle(
                isHovering: isSelected,
                isActive: isActive
            )
        )
        .onHover { hover in
            withAnimation(animationFast) {
                isHovering = hover
            }
        }
    }
}

struct PickerSection<V>: Identifiable, Hashable where V: Hashable, V: Identifiable {
    var id: String { title }

    let title: String
    let items: [V]

    init(_ title: String, _ items: [V]) {
        self.title = title
        self.items = items
    }
}

struct SearchablePickerButtonStyle: ButtonStyle {
    @Environment(\.luminareAnimationFast) private var animationFast
    @Environment(\.luminarePopupPadding) private var luminarePopupPadding
    @Environment(\.luminarePopupCornerRadii) private var luminarePopupCornerRadii

    private var cornerRadius: CGFloat {
        luminarePopupCornerRadii.topLeading - luminarePopupPadding / 2
    }

    let isHovering: Bool
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    Rectangle()
                        .foregroundStyle(.quaternary)
                } else if isActive {
                    Rectangle()
                        .foregroundStyle(.quaternary.opacity(0.7))
                }

                if isHovering {
                    Rectangle()
                        .foregroundStyle(.quaternary.opacity(0.7))
                }

                if isActive {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
            }
            .animation(animationFast, value: [isActive, configuration.isPressed])
            .clipShape(.rect(cornerRadius: cornerRadius))
    }
}
