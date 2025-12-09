//
//  PickerList.swift
//  Loop
//
//  Created by Kai Azim on 2024-08-25.
//

import Luminare
import Scribe
import SwiftUI

struct PickerList<Content, V>: View where Content: View, V: Hashable, V: Identifiable {
    @EnvironmentObject private var popover: LuminarePopupPanel

    @Binding var selection: V
    @Binding var searchResults: [V]

    @State private var arrowSelection: V?
    @State private var eventMonitor: LocalEventMonitor?
    @State private var isInitialRender = true

    private let padding: CGFloat
    private let sections: [PickerSection<V>]
    private let content: (V) -> Content

    init(
        _ selection: Binding<V>,
        _ searchResults: Binding<[V]>,
        _ padding: CGFloat,
        _ sections: [PickerSection<V>],
        @ViewBuilder content: @escaping (V) -> Content
    ) {
        self._selection = selection
        self._searchResults = searchResults
        self.sections = sections
        self.padding = padding
        self.content = content
    }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: padding) {
                    contentStack(reader: reader)
                }
                .padding(padding / 2)
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
            Log.info("Stopping event monitor", category: .pickerView)
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
                        content: content,
                        padding: padding / 2
                    )
                    .id(item)
                }
            } header: {
                Text(section.title)
                    .foregroundStyle(.secondary)
                    .padding(.leading, padding / 2)
                    .padding(.top, padding / 2)
            }
        }
    }

    private var searchResultsView: some View {
        ForEach(searchResults) { item in
            PopoverPickerItem(
                selection: $selection,
                arrowSelection: arrowSelection,
                item: item,
                content: content,
                padding: padding / 2
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
            Log.error("Invalid nextIndex: \(nextIndex), items count: \(items.count)", category: .pickerView)
            return
        }

        let newSelection = items[nextIndex]
        arrowSelection = newSelection

        /// Only scroll if the selection is valid and not nil
        guard let validSelection = arrowSelection else {
            Log.info("arrowSelection is nil, skipping scroll", category: .pickerView)
            return
        }

        reader.scrollTo(validSelection, anchor: .center)
    }
}

struct PopoverPickerItem<Content, V>: View where Content: View, V: Hashable {
    @EnvironmentObject private var popover: LuminarePopupPanel
    @Environment(\.luminareAnimationFast) private var animationFast

    @State private var isHovering = false
    @Binding var selection: V
    let arrowSelection: V?
    let item: V
    let content: (V) -> Content
    let padding: CGFloat

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
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.luminare)
        .luminareFilledStates([.hovering, .pressed])
        .luminareBorderedStates(.hovering)
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
