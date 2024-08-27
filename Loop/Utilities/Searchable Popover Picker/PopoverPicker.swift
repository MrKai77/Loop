//
//  PopoverPicker.swift
//  Loop
//
//  Created by Kai Azim on 2024-08-25.
//

import Luminare
import SwiftUI

struct PickerView<Content, V>: View where Content: View, V: Hashable, V: Identifiable {
    @EnvironmentObject var popover: PopoverPanel

    @Binding var selection: V
    @Binding var searchResults: [V]
    @State var arrowSelection: V?

    let sections: [PickerSection<V>]
    let content: (V) -> Content // for each item

    @State var eventMonitor: EventMonitor?

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
                VStack(spacing: PopoverPanel.sectionPadding) {
                    VStack(alignment: .leading, spacing: 4) {
                        if searchResults.isEmpty {
                            ForEach(sections) { section in
                                Text(section.title)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, PopoverPanel.contentPadding)
                                    .padding(.top, PopoverPanel.sectionPadding)

                                ForEach(section.items, id: \.self) { i in
                                    PopoverPickerItem(selection: $selection, arrowSelection: $arrowSelection, item: i, content: content)
                                        .id(i)
                                }
                            }
                        } else {
                            ForEach(searchResults) { i in
                                PopoverPickerItem(selection: $selection, arrowSelection: $arrowSelection, item: i, content: content)
                                    .id(i)
                            }
                        }
                    }
                    .onChange(of: searchResults) { _ in
                        arrowSelection = nil
                    }
                    .onAppear {
                        setupEventMonitor(reader: reader)
                        eventMonitor?.start()

                        popover.closeHandler = {
                            eventMonitor?.stop()
                            eventMonitor = nil
                        }
                    }
                }
                .padding(PopoverPanel.contentPadding)
            }
        }
    }

    func setupEventMonitor(reader: ScrollViewProxy) {
        eventMonitor = NSEventMonitor(scope: .local, eventMask: [.keyDown]) { event in
            if event.keyCode == .kVK_DownArrow {
                if searchResults.isEmpty {
                    if arrowSelection == nil || arrowSelection == sections.last?.items.last {
                        arrowSelection = sections.first?.items.first
                    } else {
                        var lastScannedItem: V? = nil
                        outerloop: for section in sections {
                            for item in section.items {
                                if lastScannedItem == arrowSelection {
                                    arrowSelection = item
                                    break outerloop
                                }

                                lastScannedItem = item
                            }
                        }
                    }
                } else {
                    if arrowSelection == nil || !searchResults.contains(arrowSelection!) {
                        if searchResults.contains(selection) {
                            var lastScannedItem: V? = nil
                            for item in searchResults {
                                if lastScannedItem == selection {
                                    arrowSelection = item
                                    break
                                }

                                lastScannedItem = item
                            }
                        } else {
                            arrowSelection = searchResults.first
                        }
                    } else if arrowSelection == searchResults.last {
                        arrowSelection = searchResults.first
                    } else {
                        var lastScannedItem: V? = nil
                        for item in searchResults {
                            if lastScannedItem == arrowSelection {
                                arrowSelection = item
                                break
                            }

                            lastScannedItem = item
                        }
                    }
                }
                reader.scrollTo(arrowSelection, anchor: .center)

                return nil
            }

            if event.keyCode == .kVK_UpArrow {
                if searchResults.isEmpty {
                    if arrowSelection == nil || arrowSelection == sections.first?.items.first {
                        arrowSelection = sections.last?.items.last
                    } else {
                        var lastScannedItem: V? = nil
                        outerloop: for section in sections.reversed() {
                            for item in section.items.reversed() {
                                if lastScannedItem == arrowSelection {
                                    arrowSelection = item
                                    break outerloop
                                }

                                lastScannedItem = item
                            }
                        }
                    }
                } else {
                    if arrowSelection == nil || !searchResults.contains(arrowSelection!) {
                        if searchResults.contains(selection) {
                            var lastScannedItem: V? = nil
                            for item in searchResults.reversed() {
                                if lastScannedItem == selection {
                                    arrowSelection = item
                                    break
                                }

                                lastScannedItem = item
                            }
                        } else {
                            arrowSelection = searchResults.last
                        }
                    } else if arrowSelection == searchResults.first {
                        arrowSelection = searchResults.last
                    } else {
                        var lastScannedItem: V? = nil
                        for item in searchResults.reversed() {
                            if lastScannedItem == arrowSelection {
                                arrowSelection = item
                                break
                            }

                            lastScannedItem = item
                        }
                    }
                }
                reader.scrollTo(arrowSelection, anchor: .center)

                return nil
            }

            if event.keyCode == .kVK_Return, let arrowSelection {
                selection = arrowSelection
                popover.close()

                return nil
            }

            if event.keyCode == .kVK_Escape {
                popover.close()

                return nil
            }

            return event
        }
    }
}

struct PopoverPickerItem<Content, V>: View where Content: View, V: Hashable {
    @EnvironmentObject var popover: PopoverPanel

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
                .padding(PopoverPanel.contentPadding)
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
    var cornerRadius: CGFloat {
        PopoverPanel.cornerRadius - PopoverPanel.contentPadding
    }

    @Binding var isHovering: Bool
    @Binding var isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    Rectangle().foregroundStyle(.quaternary)
                } else if isActive {
                    Rectangle().foregroundStyle(.quaternary.opacity(0.7))
                }

                if isHovering {
                    Rectangle().foregroundStyle(.quaternary.opacity(0.7))
                }
            }
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: PopoverPanel.cornerRadius - PopoverPanel.contentPadding)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
            }
            .animation(LuminareSettingsWindow.fastAnimation, value: [isHovering, isActive, configuration.isPressed])
            .clipShape(.rect(cornerRadius: cornerRadius))
    }
}
