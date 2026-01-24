//
//  ChangelogSectionView.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-23.
//

import Luminare
import SwiftUI

struct ChangelogSectionView: View, Equatable {
    @Environment(\.luminareAnimation) var luminareAnimation

    let isExpanded: Bool
    let title: String
    let notes: [ChangelogNote]
    let onToggle: () -> ()

    var body: some View {
        LuminareSection {
            ChangelogSectionHeader(
                isExpanded: isExpanded,
                title: title,
                onToggle: onToggle
            )
            .equatable()

            if isExpanded {
                ForEach(notes, id: \.id) { note in
                    ChangelogItemView(note: note)
                        .equatable()
                }
            }
        }
    }

    static func == (lhs: ChangelogSectionView, rhs: ChangelogSectionView) -> Bool {
        lhs.isExpanded == rhs.isExpanded &&
            lhs.title == rhs.title &&
            lhs.notes == rhs.notes
    }
}

private struct ChangelogSectionHeader: View, Equatable {
    let isExpanded: Bool
    let title: String
    let onToggle: () -> ()

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: "chevron.forward")
                    .bold()
                    .rotationEffect(isExpanded ? .degrees(90) : .zero)

                Text(LocalizedStringKey(title))
                    .font(.headline)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 34)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    static func == (lhs: ChangelogSectionHeader, rhs: ChangelogSectionHeader) -> Bool {
        lhs.isExpanded == rhs.isExpanded && lhs.title == rhs.title
    }
}

private struct ChangelogItemView: View, Equatable {
    let note: ChangelogNote

    var body: some View {
        HStack(spacing: 8) {
            Text(note.emoji)
            Text(LocalizedStringKey(note.text))
                .lineSpacing(1.1)

            Spacer(minLength: 0)

            ChangelogMetadataView(note: note)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(minHeight: 34)
    }

    static func == (lhs: ChangelogItemView, rhs: ChangelogItemView) -> Bool {
        lhs.note == rhs.note
    }
}

private struct ChangelogMetadataView: View, Equatable {
    let note: ChangelogNote

    var body: some View {
        HStack(spacing: 0) {
            if let user = note.user {
                Link(String("@\(user)"), destination: URL(string: "https://github.com/\(user)")!)
                    .frame(width: 105, alignment: .trailing)
            }

            if note.user != nil, note.reference != nil {
                Text(verbatim: "•")
                    .padding(.horizontal, 4)
            }

            if let reference = note.reference {
                Link(String("#\(reference)"), destination: URL(string: "https://github.com/MrKai77/Loop/issues/\(reference)")!)
                    .monospaced()
                    .fixedSize()
            }
        }
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .fixedSize()
    }

    static func == (lhs: ChangelogMetadataView, rhs: ChangelogMetadataView) -> Bool {
        lhs.note.user == rhs.note.user && lhs.note.reference == rhs.note.reference
    }
}
