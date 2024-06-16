//
//  UpdateView.swift
//  Loop
//
//  Created by Kami on 15/06/2024.
//

import Luminare
import SwiftUI

struct UpdateView: View {
    @ObservedObject var updater = AppDelegate.updater
    @State var isInstalling: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                theLoopTimesView()
                versionChangeView()
            }
            .padding([.top, .horizontal], 12)
            .padding(.bottom, 10)

            changelogView()
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            HStack {
                Button("Remind me later") {
                    AppDelegate.updater.dismissWindow()
                }

                Button("Install Update") {
                    AppDelegate.updater.dismissWindow()
                }
            }
            .buttonStyle(LuminareCompactButtonStyle())
            .padding(12)
            .background(VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow))
            .overlay {
                VStack {
                    Divider()
                    Spacer()
                }
            }
            .fixedSize(horizontal: false, vertical: true)

//                HStack(spacing: 2) {
//                    Button("Remind me later") {
//                        AppDelegate.updater.dismissWindow()
//                    }
//                    .buttonStyle(LuminareButtonStyle())
//
//                    Button(
//                        action: {
//                            if !isInstalling {
//                                withAnimation {
//                                    isInstalling.toggle()
//                                }
//                                Task {
//                                    await AppDelegate.updater.installUpdate()
//                                }
//                            } else if updater.progressBar.1 == 1.0 {
//                                AppDelegate.updater.dismissWindow()
//                                AppDelegate.relaunch()
//                            }
//                        },
//                        label: {
//                            if updater.progressBar.1 < 1.0 {
//                                Text(isInstalling ? "Downloading & installing..." : "Install")
//                            } else {
//                                Text("Restart to complete")
//                            }
//                        }
//                    )
//
//                    .buttonStyle(LuminareButtonStyle())
//                    .overlay {
//                        if isInstalling {
//                            GeometryReader { geo in
//                                Rectangle()
//                                    .foregroundStyle(.tertiary)
//                                    .clipShape(.rect(cornerRadius: 4))
//                                    .frame(width: CGFloat(updater.progressBar.1) * geo.size.width)
//                                    .animation(.easeIn(duration: 1), value: updater.progressBar.1)
//                            }
//                            .allowsHitTesting(false)
//                            .opacity(updater.progressBar.1 < 1.0 ? 1 : 0)
//                        }
//                    }
//                }
//                .frame(height: 42)
//            }
        }
        .frame(width: 570, height: 480)
    }

    func theLoopTimesView() -> some View {
        ZStack {
            TheLoopTimes()
                .fill(
                    .shadow(.inner(color: .black.opacity(0.1), radius: 3))
                    .shadow(.inner(color: .black.opacity(0.3), radius: 5, y: 3))
                )
                .foregroundStyle(.white.opacity(0.7))
                .blendMode(.overlay)

            TheLoopTimes()
                .stroke(.white.opacity(0.1), lineWidth: 1)
                .blendMode(.luminosity)
        }
        .aspectRatio(883.88 / 135.53, contentMode: .fit)
        .frame(width: 450)
    }

    func versionChangeView() -> some View {
        HStack {
            Text(Bundle.main.appVersion ?? "Unknown")
            Image(systemName: "arrow.right")
            Text(updater.availableReleases.first?.tagName ?? "Unknown")
        }
        .font(.title3)
        .blendMode(.overlay)
    }

    func changelogView() -> some View {
        ScrollView {
            VStack {
                ForEach(updater.changelog, id: \.title) { item in
                    ChangelogSectionView(item: item)
                }
            }
            .padding(.top, 10)
            .padding(12)
        }
    }
}

struct ChangelogSectionView: View {
    let item: (title: String, body: [String])
    @State var isExpanded = false

    var body: some View {
        LuminareSection {
            Button {
                withAnimation(.smooth(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .bold()
                        .rotationEffect(isExpanded ? .degrees(90) : .zero)

                    Text(LocalizedStringKey(item.title))
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .frame(height: 34)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(item.body, id: \.self) { line in
                    let emoji = line.prefix(1)
                    let note = line
                        .suffix(line.count - 1)
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    HStack(spacing: 8) {
                        Text(emoji)
                        Text(LocalizedStringKey(note))
                            .lineSpacing(1.1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(minHeight: 34)
                }
            }
        }
    }
}
