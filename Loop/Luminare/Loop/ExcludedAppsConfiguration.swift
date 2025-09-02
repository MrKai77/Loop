//
//  ExcludedAppsConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-05-25.
//

import Defaults
import Luminare
import SwiftUI

struct ExcludedAppsConfigurationView: View {
    @Environment(\.luminareAnimation) private var luminareAnimation

    @Default(.excludedApps) private var excludedApps
    @State private var selectedApps = Set<URL>()

    var body: some View {
        LuminareSection {
            HStack(spacing: 2) {
                Button("Add") {
                    showAppChooser()
                }

                Button("Remove", role: .destructive) {
                    excludedApps.removeAll { selectedApps.contains($0) }
                }
                .disabled(selectedApps.isEmpty)
                .buttonStyle(.luminareProminent)
                .keyboardShortcut(.delete)
            }

            LuminareList(
                items: $excludedApps,
                selection: $selectedApps,
                id: \.self
            ) { item in
                AppView(url: item)
                    .equatable()
            } emptyView: {
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
            }
            .luminareListRoundedCorner(bottom: .always)
        }
    }

    func showAppChooser() {
        Task { @MainActor in
            guard let window = LuminareManager.shared.window else { return }

            let panel = NSOpenPanel()
            panel.worksWhenModal = true
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.application]
            panel.allowsOtherFileTypes = false
            panel.resolvesAliases = true
            panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first

            let result = await panel.beginSheetModal(for: window)

            if result == .OK {
                let appsToAdd = panel.urls.compactMap { excludedApps.contains($0) ? nil : $0 }
                excludedApps.append(contentsOf: appsToAdd)
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
                Image(.finder)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(4)
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

            Task { @MainActor in
                let icon = NSWorkspace.shared.icon(forFile: path)
                self.icon = icon
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
