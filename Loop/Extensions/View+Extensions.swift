//
//  View+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import SwiftUI

// Make it easier to recieve notifications SwiftUI views
extension View {
    func onReceive(
        _ name: Notification.Name,
        center: NotificationCenter = .default,
        object: AnyObject? = nil,
        perform action: @escaping (Notification) -> Void
    ) -> some View {
        onReceive(
            center.publisher(for: name, object: object),
            perform: action
        )
    }
}

// Used in Keybindings settings tab
struct Backport<Content> {
    let content: Content
}

extension View {
    var backport: Backport<Self> { Backport(content: self) }
}

extension Backport where Content: View {
    @ViewBuilder func symbolEffectPulse(wholeSymbol: Bool = false) -> some View {
        if #available(macOS 14, *) {
            if wholeSymbol {
                content.symbolEffect(.pulse.wholeSymbol)
            }
            else {
                content.symbolEffect(.pulse)
            }
        } else {
            content
        }
    }
}
