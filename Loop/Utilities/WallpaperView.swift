//
//  WallpaperView.swift
//  Loop
//
//  Created by Kai Azim on 2024-02-01.
//

import SwiftUI

// By making this equatable, we won't refresh the view everytime something else changes
// Make sure to apply .equatable()
struct WallpaperView: View, Equatable {
    static func == (lhs: WallpaperView, rhs: WallpaperView) -> Bool {
        true
    }

    var body: some View {
        if let screen = NSScreen.screenWithMouse,
           let url = NSWorkspace.shared.desktopImageURL(for: screen),
           let image = NSImage(contentsOf: url) {
            GeometryReader { geo in
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .allowsHitTesting(false)
        }
    }
}
