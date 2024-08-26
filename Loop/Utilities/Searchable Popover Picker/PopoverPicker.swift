//
//  PopoverPicker.swift
//  Loop
//
//  Created by Kai Azim on 2024-08-25.
//

import Luminare
import SwiftUI

struct PopoverPickerSection<Content, V>: View where Content: View, V: Hashable {
    let title: String
    let items: [V]
    @Binding var searchResults: [V]
    @Binding var selection: V
    let content: (V) -> Content

    init(
        _ title: String,
        _ items: [V],
        _ searchResults: Binding<[V]>,
        _ selection: Binding<V>,
        @ViewBuilder content: @escaping (V) -> Content
    ) {
        self.title = title
        self.items = items
        self._searchResults = searchResults
        self._selection = selection
        self.content = content
    }

    var body: some View {
        let result = searchResults.filter { items.contains($0) }

        if !result.isEmpty {
            VStack(spacing: 8) {
                Text(title)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(result, id: \.self) { i in
                        PopoverPickerItem(selection: $selection, item: i, content: content)

                        if i != items.last {
                            Divider()
                                .padding(.horizontal, 1)
                                .opacity(0.5)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.quaternary.opacity(0.5), lineWidth: 1)
                }
            }
        }
    }
}

struct PopoverPickerItem<Content, V>: View where Content: View, V: Hashable {
    @EnvironmentObject var popover: PopoverPanel

    @Binding var selection: V
    @State var isHovering = false
    let item: V
    let content: (V) -> Content

    var body: some View {
        Button {
            selection = item
            popover.close()
        } label: {
            content(item)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background {
                    if isHovering {
                        Rectangle()
                            .foregroundStyle(.quaternary)
                    }
                }
                .background(.quinary.opacity(0.5))
                .onHover { isHovering in
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.isHovering = isHovering
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
