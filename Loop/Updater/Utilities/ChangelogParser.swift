//
//  ChangelogParser.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-23.
//

import Foundation
import Scribe

@Loggable(style: .static)
enum ChangelogParser {
    static func parse(_ body: String) -> [ChangelogSection] {
        var result: [ChangelogSection] = []

        let lines = body.split(whereSeparator: \.isNewline)
        var currentSectionID: String?
        var totalNotesCount = 0

        for line in lines where !line.isEmpty {
            if let header = parseHeader(from: line) {
                currentSectionID = header

                if result.first(where: { $0.id == header }) == nil {
                    let emoji = detectEmoji(line: header)

                    if emoji == nil {
                        log.warn("Failed to parse emoji in:  \(header)")
                    }

                    let title = header
                        .drop { $0.hasEmojiPresentationAsDefault }
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    let newSection = ChangelogSection(
                        id: header, // uses full header name for id
                        emoji: emoji ?? "🔄",
                        title: title,
                        notes: []
                    )

                    log.debug("Parsed new section: '\(newSection.title)'")

                    result.append(newSection)
                }

                continue
            }

            if let note = parseNote(from: line) {
                guard let index = result.firstIndex(where: { $0.id == currentSectionID }) else {
                    // If the section doesn't exist (e.g. malformed changelog ordering), skip safely.
                    log.warn("Failed to find section for '\(currentSectionID ?? "")'")
                    continue
                }

                result[index].notes.append(note)
                totalNotesCount += 1

                continue
            }

            log.debug("Skipping line: '\(line)'")
        }

        let sectionsToRemove = result.filter(\.notes.isEmpty)
        if !sectionsToRemove.isEmpty {
            result.removeAll { sectionsToRemove.contains($0) }
            log.debug("Removed empty changelog sections: \(sectionsToRemove.map(\.id))")
        }

        log.success("Finished parsing changelog with a total of \(totalNotesCount) notes")

        return result
    }

    private static func parseHeader(from line: Substring) -> String? {
        guard line.starts(with: "#") else { return nil }

        let header = line
            .replacing(/#/, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return header.isEmpty ? nil : header
    }

    private static func parseNote(from line: Substring) -> ChangelogNote? {
        guard line.hasPrefix("- ") else {
            return nil
        }

        let cleanedLine = line
            .replacing(#/- /#, with: "")
            .trimmingCharacters(in: .whitespaces)

        let user: String?
        let reference: Int?

        if let match = cleanedLine.firstMatch(of: /(@(?<user>\w+))/) {
            user = String(match.user)
        } else {
            user = nil
        }

        if let match = cleanedLine.firstMatch(of: /#(?<reference>\d+)/) {
            reference = Int(String(match.reference))
        } else {
            reference = nil
        }

        let noteText = cleanedLine
            .replacing(#/#\d+/#, with: "") // Issue #
            .replacing(#/(@.*?)/#, with: "") // Mentions
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let emoji = detectEmoji(line: noteText)
        let text = noteText
            .drop { $0.hasEmojiPresentationAsDefault }
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ChangelogNote(
            emoji: emoji,
            text: String(text),
            user: user,
            reference: reference
        )
    }

    private static func detectEmoji(line: String) -> Character? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            log.warn("Failed to detect emoji inside '\(line)'; empty string")
            return nil
        }

        for char in trimmed {
            let hasEmoji = char.unicodeScalars.contains { scalar in
                scalar.properties.isEmoji || scalar.properties.isEmojiPresentation
            }

            if hasEmoji {
                return char
            }
        }

        return nil
    }
}

// MARK: - ChangelogSection

struct ChangelogSection: Identifiable, Equatable {
    let id: String
    let emoji: Character
    let title: String
    var notes: [ChangelogNote]
}

// MARK: - ChangelogNote

struct ChangelogNote: Identifiable, Equatable {
    let id: UUID = .init()
    let emoji: Character?
    let text: String
    let user: String?
    let reference: Int?
}

// MARK: - Character emoji detection

private extension Character {
    var hasEmojiPresentationAsDefault: Bool {
        let scalars = unicodeScalars

        // Must contain at least one emoji-capable scalar
        guard scalars.contains(where: \.properties.isEmoji) else {
            return false
        }

        // If any scalar defaults to emoji, it's an emoji
        if scalars.contains(where: \.properties.isEmojiPresentation) {
            return true
        }

        // If it contains the emojification codepoint (U+FE0F, Variation Selector-16)
        if scalars.contains(where: { $0.value == 0xFE0F }) {
            return true
        }

        return false
    }
}
