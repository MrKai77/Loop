//
//  PopoverPicker.swift
//  Loop
//
//  Created by Kai Azim on 2024-08-25.
//

import Luminare
import SwiftUI

struct PickerView<Content, V>: View where Content: View, V: Hashable, V: Identifiable {
    @EnvironmentObject var popover: LuminarePopupPanel
    @Environment(\.luminarePopupPadding) private var luminarePopupPadding

    @Binding var selection: V
    @Binding var searchResults: [V]

    @State private var arrowSelection: V?
    @State private var eventMonitor: EventMonitor?

    let sections: [PickerSection<V>]
    let content: (V) -> Content

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
            ScrollView {
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
            setupEventMonitor(reader: reader)
            eventMonitor?.start()
        }
        .onDisappear {
            print("Stopping event monitor")
            eventMonitor?.stop()
            eventMonitor = nil
        }
    }

    private var sectionsView: some View {
        ForEach(sections) { section in
            Section {
                ForEach(section.items, id: \.self) { item in
                    PopoverPickerItem(
                        selection: $selection,
                        arrowSelection: $arrowSelection,
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
                arrowSelection: $arrowSelection,
                item: item,
                content: content
            )
            .id(item)
        }
    }

    private func setupEventMonitor(reader: ScrollViewProxy) {
        eventMonitor = NSEventMonitor(scope: .local, eventMask: [.keyDown]) { event in
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
        let nextIndex = (currentIndex + (increment ? 1 : -1) + items.count) % items.count

        /// Ensure nextIndex is valid
        guard nextIndex >= 0, nextIndex < items.count else {
            print("Invalid nextIndex: \(nextIndex), items count: \(items.count)")
            return
        }

        let newSelection = items[nextIndex]
        arrowSelection = newSelection

        /// Only scroll if the selection is valid and not nil
        guard let validSelection = arrowSelection else {
            print("arrowSelection is nil, skipping scroll")
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                reader.scrollTo(validSelection, anchor: .center)
            }
        }
    }
}

struct PopoverPickerItem<Content, V>: View where Content: View, V: Hashable {
    @EnvironmentObject var popover: LuminarePopupPanel
    @Environment(\.luminarePopupPadding) private var luminarePopupPadding

    @State var isHovering = false
    @Binding var selection: V
    @Binding var arrowSelection: V?
    @State var isActive = false
    let item: V
    let content: (V) -> Content

    var body: some View {
        Button {
            Task {
                await MainActor.run {
                    selection = item
                }
            }
            popover.resignKey()
        } label: {
            content(item)
                .padding(luminarePopupPadding / 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(SearchablePickerButtonStyle(isHovering: $isHovering, isActive: $isActive))
        .onHover { hover in
            isHovering = hover
            arrowSelection = hover ? item : nil
        }
        .onChange(of: arrowSelection) { _ in
            isHovering = arrowSelection == item
        }
        .onAppear {
            isActive = selection == item
        }
        .onChange(of: selection) { _ in
            isActive = selection == item
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

    var cornerRadius: RectangleCornerRadii {
        .init(
            topLeading: luminarePopupCornerRadii.topLeading - luminarePopupPadding / 2,
            bottomLeading: luminarePopupCornerRadii.topLeading - luminarePopupPadding / 2,
            bottomTrailing: luminarePopupCornerRadii.topLeading - luminarePopupPadding / 2,
            topTrailing: luminarePopupCornerRadii.topLeading - luminarePopupPadding / 2
        )
    }

    @Binding var isHovering: Bool
    @Binding var isActive: Bool

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
            }
            .overlay {
                if isActive {
                    UnevenRoundedRectangle(cornerRadii: cornerRadius)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
            }
            .animation(animationFast, value: [isHovering, isActive, configuration.isPressed])
            .clipShape(.rect(cornerRadii: cornerRadius))
    }
}
