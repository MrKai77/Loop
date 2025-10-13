//
//  ScreenView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-14.
//

import SwiftUI

public struct ScreenView<Content>: View where Content: View {
    @Environment(\.luminareTintColor) private var tintColor
    @Environment(\.luminareAnimationFast) private var animationFast

    let isBlurred: Bool
    let content: () -> Content

    @State private var image: NSImage?

    private let screenShape = UnevenRoundedRectangle(
        topLeadingRadius: 12,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: 12
    )

    public init(
        isBlurred: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isBlurred = isBlurred
        self.content = content
    }

    public var body: some View {
        ZStack {
            GeometryReader { proxy in
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .blur(radius: isBlurred ? 10 : 0)
                        .opacity(isBlurred ? 0.5 : 1)
                } else {
                    tintColor
                        .opacity(0.1)
                }
            }
            .allowsHitTesting(false)
            .overlay {
                content()
                    .padding(5)
            }
            .clipShape(screenShape)

            screenShape
                .stroke(.gray, lineWidth: 2)

            screenShape
                .inset(by: 2.5)
                .stroke(.black, lineWidth: 5)

            screenShape
                .inset(by: 3)
                .stroke(.gray.opacity(0.2), lineWidth: 1)
        }
        .aspectRatio(16 / 10, contentMode: .fill)
        .task {
            guard let fetchedImage = await fetchImage() else {
                return
            }

            await MainActor.run {
                withAnimation(animationFast) {
                    image = fetchedImage
                }
            }
        }
    }

    func fetchImage() async -> NSImage? {
        let wallpaperImageFetcher = WallpaperImageFetcher()
        guard let image = try? await wallpaperImageFetcher.takeScreenshot() else {
            return nil
        }

        let aspectRatio = image.size.width / image.size.height
        let resizedImage = image.resized(to: .init(width: 300 * aspectRatio, height: 300))

        return resizedImage
    }
}
