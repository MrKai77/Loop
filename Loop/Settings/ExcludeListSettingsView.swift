//
//  ExcludeListSettingsView.swift
//  Loop
//
//  Created by Dirk Mika on 11.03.24.
//

import SwiftUI
import Defaults

struct ExcludeListSettingsView: View {
    @EnvironmentObject var appListManager: AppListManager

    @Default(.applicationExcludeList) var excludeList

    @State private var selection: String?

    var body: some View {
        ZStack {
            Form {
                Section {
                    VStack(spacing: 0) {
                        if self.excludeList.isEmpty {
                            HStack {
                                Spacer()
                                VStack {
                                    Text("No excluded applications")
                                        .font(.title3)
                                    Text("Press + to add an application!")
                                        .font(.caption)
                                }
                                Spacer()
                            }
                            .foregroundStyle(.secondary)
                            .padding()
                        } else {
                            List(selection: $selection) {
                                ForEach(excludeList, id: \.self) { entry in
                                    if let app = appListManager.installedApps.first(where: { $0.bundleID == entry }) {
                                        Label {
                                            Text(app.displayName)
                                                .padding(.leading, 8)
                                        } icon: {
                                            Image(nsImage: app.icon)
                                        }
                                    } else {
                                        Text(entry)
                                    }
                                }
                            }
                            .listStyle(.bordered(alternatesRowBackgrounds: true))
                        }

                        Divider()

                        Rectangle()
                            .frame(height: 20)
                            .foregroundStyle(.quinary)
                            .overlay {
                                HStack(spacing: 5) {
                                    Menu(content: {
                                        installedAppsMenu()
                                    }, label: {
                                        Rectangle()
                                            .foregroundStyle(.white.opacity(0.00001))
                                            .overlay {
                                                Image(systemName: "plus")
                                                    .font(.footnote)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .aspectRatio(1, contentMode: .fit)
                                            .padding(-5)
                                    })

                                    Divider()

                                    Button {
                                        self.excludeList.removeAll(where: {
                                            $0 == selection
                                        })
                                    } label: {
                                        Rectangle()
                                            .foregroundStyle(.white.opacity(0.00001))
                                            .overlay {
                                                Image(systemName: "minus")
                                                    .font(.footnote)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .aspectRatio(1, contentMode: .fit)
                                            .padding(-5)
                                    }
                                    .disabled(self.selection == nil)

                                    Spacer()
                                }
                                .buttonStyle(.plain)
                                .padding(5)
                            }
                    }
                    .ignoresSafeArea()
                    .padding(-10)
                } header: {
                    VStack(alignment: .leading) {
                        Text("Excluded applications")
                        Text("Applications in the exclude list are ignored by Loop.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    @ViewBuilder
    func installedAppsMenu() -> some View {
        let apps = appListManager.installedApps
            .filter({ !self.excludeList.contains($0.bundleID) })
            .grouped(by: { $0.installationFolder })
        let installationFolders = apps.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })

        ForEach(installationFolders, id: \.self) { folder in
            Section(folder) {
                let appsInFolder = apps[folder]!.sorted(by: { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending })
                ForEach(appsInFolder) { app in
                    Button(action: {
                        self.excludeList.append(app.bundleID)
                    }, label: {
                        Label {
                            Text(app.displayName)
                        } icon: {
                            Image(nsImage: app.icon)
                        }
                    })
                }
            }
        }
    }
}

#Preview {
    ExcludeListSettingsView()
        .environmentObject(AppListManager())
}
