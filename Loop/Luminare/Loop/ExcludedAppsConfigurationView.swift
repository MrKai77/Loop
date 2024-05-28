//
//  ExcludedAppsConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-25.
//

import SwiftUI
import Luminare
import Defaults

struct ExcludedAppsConfigurationView: View {
    @State var excludedApps = Defaults[.excludedApps]
    @State private var selectedApps = Set<URL>()

    var body: some View {
        LuminareList(
            items: $excludedApps,
            selection: $selectedApps,
            addAction: {
                showAppChooser()
            },
            content: { url in
                AppView(url: url)
                    .equatable()
            },
            emptyView: {
                HStack {
                    Spacer()
                    VStack {
                        Text("No excluded applications")
                            .font(.title3)
                        Text("Press \"Add\" to add an application")
                            .font(.caption)
                    }
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding()
            },
            id: \.self
        )
        .onChange(of: excludedApps) { _ in
            Defaults[.excludedApps] = excludedApps
        }
        .onAppear {
            excludedApps = Defaults[.excludedApps]
        }
    }

    func showAppChooser() {
        DispatchQueue.main.async {
            guard let window = LuminareManager.window else { return }
            let panel = NSOpenPanel()
            panel.worksWhenModal = true
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.application]
            panel.allowsOtherFileTypes = false
            panel.resolvesAliases = true
            panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first
            panel.beginSheetModal(for: window) { result in
                if result == .OK {
                    let appsToAdd = panel.urls.compactMap { excludedApps.contains($0) ? nil : $0 }

                    withAnimation(.smooth(duration: 0.25)) {
                        excludedApps.append(contentsOf: appsToAdd)
                    }
                }
            }
        }
    }
}

struct AppView: View, Equatable {
    @ObservedObject var app: App

    init(url: Binding<URL>) {
        self.app = App(url: url.wrappedValue) ?? App(
            bundleID: "unknown",
            displayName: url.wrappedValue.lastPathComponent,
            path: url.wrappedValue.relativePath,
            url: url.wrappedValue.absoluteURL,
            icon: .init(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon)
                } else {
                    ProgressView()
                }
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading) {
                Text(app.displayName)

                Text(app.path)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Spacer()

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.app.url == rhs.app.url
    }

    class App: Identifiable, ObservableObject {
        var id: String { bundleID }
        let bundleID: String
        @Published var icon: NSImage?
        let displayName: String
        let path: String
        let url: URL

        init?(url: URL) {
            guard
                let meta = NSMetadataItem(url: url),
                let bundleId = meta.value(forAttribute: NSMetadataItemCFBundleIdentifierKey) as? String,
                let displayName = meta.value(forAttribute: NSMetadataItemDisplayNameKey) as? String,
                let path = meta.value(forAttribute: NSMetadataItemPathKey) as? String
            else {
                return nil
            }

            self.bundleID = bundleId
            self.displayName = displayName
            self.path = path
            self.url = url

            DispatchQueue.main.async {
                self.icon = NSWorkspace.shared.icon(forFile: self.path)
            }
        }

        init(bundleID: String, displayName: String, path: String, url: URL, icon: NSImage? = nil) {
            self.bundleID = bundleID
            self.displayName = displayName
            self.path = path
            self.url = url
            self.icon = icon
        }
    }
}
