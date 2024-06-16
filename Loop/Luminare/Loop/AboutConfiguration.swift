//
//  AboutConfiguration.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-26.
//

import AppKit
import Combine
import Defaults
import Luminare
import SwiftUI

class AppState: ObservableObject {
  @Published var releases = [Release]()
  @Published var progressBar: (String, Double) = ("Ready", 0.0)
  @Published var currentReleaseInfo: String = ""
  @Published var changelogText: String = ""
  @Published var currentVersion: String =
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
  @Published var remindLater: Bool = false
  @Published var updateAvailable: Bool = false
}

enum NewWindow: Int {
  case update
  case no_update
}

class AboutConfigurationModel: ObservableObject {
  let currentIcon = Defaults[.currentIcon]  // no need for didSet since it won't change here

  @Published var isHoveringOverVersionCopier = false

  @Published var includeDevelopmentVersions = Defaults[.includeDevelopmentVersions] {
    didSet {
      Defaults[.includeDevelopmentVersions] = includeDevelopmentVersions
    }
  }

  let credits: [CreditItem] = [
    .init(
      "Kai",
      "Development",
      url: .init(string: "https://github.com/mrkai77")!,
      avatar: Image(.kai)
    ),
    .init(
      "Jace",
      "Design",
      url: .init(string: "https://x.com/jacethings")!,
      avatar: Image(.jace)
    ),
    .init(
      "Kami",
      "Development support",
      url: .init(string: "https://github.com/senpaihunters")!,
      avatar: Image(.kami)
    ),
    .init(
      "Greg Lassale",
      "Icon contributor",
      url: .init(string: "https://x.com/greglassale")!,
      avatar: Image(.greglassale)
    ),
    .init(
      "JSDev",
      "Icon contributor",
      url: .init(string: "https://github.com/N-coder82")!,
      avatar: Image(.jsdev)
    ),
    .init(
      "Contributors on GitHub",
      "Some features, ideas, and bug fixes",
      url: .init(string: "https://github.com/MrKai77/Loop/graphs/contributors")!,
      avatar: Image(.github)
    ),
  ]

  func copyVersionToClipboard() {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(
      "Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))",
      forType: NSPasteboard.PasteboardType.string
    )
  }
}

struct CreditItem: Identifiable {
  var id: String { name }

  let name: String
  let description: LocalizedStringKey?
  let url: URL
  let avatar: Image

  init(_ name: String, _ description: LocalizedStringKey? = nil, url: URL, avatar: Image) {
    self.name = name
    self.description = description
    self.avatar = avatar
    self.url = url
  }
}

struct AboutConfigurationView: View {
  @Environment(\.openURL) private var openURL
  @StateObject private var model = AboutConfigurationModel()
  @Default(.timesLooped) var timesLooped
  @StateObject private var appState = AppState()
  @State private var updateCheckCancellable: AnyCancellable?


  /// you can customise this if you wish
  private func setUpAutoUpdateCheck() {
    updateCheckCancellable?.cancel()  // Cancel any existing timer
    updateCheckCancellable = Timer.publish(every: 21600, on: .main, in: .common)
      .autoconnect()
      .sink { _ in
        Updater.shared.pullFromGitHub(appState: appState, manual: false)
      }
  }

  private func handleUpdateAvailableChange(isUpdateAvailable: Bool) {
    if isUpdateAvailable {
      NewWin.show(appState: appState, width: 500, height: 440, newWin: .update)
    } else {
      // Consider handling the 'no update' case or remove this block if not needed.
    }
  }

  var body: some View {
    LuminareSection {
      Button {
        model.copyVersionToClipboard()
      } label: {
        HStack {
          if let image = NSImage(named: model.currentIcon) {
            Image(nsImage: image)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(height: 60)
          }

          VStack(alignment: .leading, spacing: 2) {
            Text("Loop")
              .fontWeight(.medium)

            Text(
              model.isHoveringOverVersionCopier
                ? "Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))"
                : "You've looped \(timesLooped) times!"
            )
            .contentTransition(.numericText(countsDown: !model.isHoveringOverVersionCopier))
            .animation(.smooth(duration: 0.25), value: model.isHoveringOverVersionCopier)
            .animation(.smooth(duration: 0.25), value: timesLooped)
            .font(.caption)
            .foregroundStyle(.secondary)
          }

          Spacer()
        }
        .padding(4)
      }
      .buttonStyle(LuminareCosmeticButtonStyle(Image(._12PxClipboard)))
      .onHover {
        model.isHoveringOverVersionCopier = $0
      }
    }

    LuminareSection {
      Button("Check for Updates") {
        Updater.shared.checkForUpdate(appState: appState, manual: true)
      }

      // I do not have the code for you to automatically check, it is hardcoded though...
      // LuminareToggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
      LuminareToggle("Include development versions", isOn: $model.includeDevelopmentVersions)
    }

    /// May want to move this somewhere nicer
    .onAppear {
      Updater.shared.pullFromGitHub(appState: appState, manual: false)
      setUpAutoUpdateCheck()
    }
    .onDisappear {
      updateCheckCancellable?.cancel()
    }
    .onChange(of: appState.updateAvailable) { newValue in
      handleUpdateAvailableChange(isUpdateAvailable: newValue)
    }
    /// end

    LuminareSection {
      VStack(alignment: .leading, spacing: 12) {
        Text(
          "Click on 'Send Feedback' to go to our GitHub page, where you can report bugs, suggest new features, or provide other valuable input."
        )

        Button("Send Feedback") {
          openURL(URL(string: "https://github.com/MrKai77/Loop")!)
        }
        .buttonStyle(LuminareCompactButtonStyle())
      }
      .padding(8)
    }

    LuminareSection("Credits") {
      ForEach(model.credits) { credit in
        creditsView(credit)
      }
    }
  }

  @ViewBuilder
  func creditsView(_ credit: CreditItem) -> some View {
    Button {
      openURL(credit.url)
    } label: {
      HStack(spacing: 12) {
        credit.avatar
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(height: 40)
          .overlay {
            Circle()
              .strokeBorder(.white.opacity(0.1), lineWidth: 1)
          }
          .clipShape(.circle)

        VStack(alignment: .leading) {
          Text(credit.name)

          if let description = credit.description {
            Text(description)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()
      }
      .padding(12)
    }
    .buttonStyle(LuminareCosmeticButtonStyle(Image(._12PxShareUpRight)))
  }
}
