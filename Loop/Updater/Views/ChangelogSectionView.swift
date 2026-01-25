//
//  ChangelogSectionView.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-23.
//

import Luminare
import SwiftUI

struct ChangelogSectionView: View {
    @Environment(\.luminareAnimation) var luminareAnimation

    let section: ChangelogSection
    let isExpanded: Bool
    let onToggle: () -> ()

    var body: some View {
        LuminareSection {
            ChangelogSectionHeader(
                section: section,
                isExpanded: isExpanded,
                onToggle: onToggle
            )

            if isExpanded {
                ForEach(section.notes, id: \.id) { note in
                    ChangelogItemView(
                        note: note,
                        sectionEmoji: section.emoji
                    )
                }
            }
        }
    }
}

private struct ChangelogSectionHeader: View {
    let section: ChangelogSection
    let isExpanded: Bool
    let onToggle: () -> ()

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top) {
                Image(systemName: "chevron.forward")
                    .rotationEffect(isExpanded ? .degrees(90) : .zero)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(String(section.emoji))
                    Text(LocalizedStringKey(section.title))
                        .lineSpacing(1.1)
                }

                Spacer()
            }
            .padding(8)
            .frame(height: 34)
            .contentShape(.rect)
            .fontWeight(.medium)
        }
        .buttonStyle(.plain)
    }
}

private struct ChangelogItemView: View {
    let note: ChangelogNote
    let sectionEmoji: Character

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(String(note.emoji ?? sectionEmoji))
                .foregroundStyle(.secondary)

            Text(LocalizedStringKey(note.text))
                .lineSpacing(1.1)

            Spacer(minLength: 0)

            ChangelogMetadataView(note: note)
        }
        .padding(8)
        .frame(minHeight: 34)
    }
}

private struct ChangelogMetadataView: View {
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
}
