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
    @State private var selection = Set<String>()

    var body: some View {
        ZStack {
            Form {
                Section {
                    VStack(spacing: 0) {
                        if self.excludeList.isEmpty {
                            HStack {
                                Spacer()
                                VStack {
                                    Text("No Excluded Applications")
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
                                ForEach(self.$excludeList, id: \.self) { entry in
                                    Group {
                                        if let app = appListManager.installedApps.first(where: {
                                            $0.bundleID == entry.wrappedValue
                                        }) {
                                            HStack {
                                                Image(nsImage: app.icon)
                                                Text(app.displayName)
                                                    .padding(.leading, 2)
                                            }
                                        } else {
                                            Text(entry.wrappedValue)
                                        }
                                    }
                                    .padding(.vertical, 5)
                                    .contextMenu {
                                        Button("Delete") {
                                            if self.selection.isEmpty {
                                                self.excludeList.removeAll(where: { $0 == entry.wrappedValue })
                                            } else {
                                                for item in selection {
                                                    self.excludeList.removeAll(where: { $0 == item })
                                                }
                                                self.selection.removeAll()
                                            }
                                        }
                                    }
                                    .tag(entry.wrappedValue)
                                }
                                .onMove { indices, newOffset in
                                    self.excludeList.move(fromOffsets: indices, toOffset: newOffset)
                                }
                                .onDelete { offset in
                                    self.excludeList.remove(atOffsets: offset)
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
                                        for item in selection {
                                            self.excludeList.removeAll(where: { $0 == item })
                                        }
                                        self.selection.removeAll()
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
                                    .disabled(self.selection.isEmpty)

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
                        Text("Excluded Applications")
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
        let installationFolders = apps.keys.sorted(by: {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        })

        ForEach(installationFolders, id: \.self) { folder in
            Section(folder) {
                let appsInFolder = apps[folder]!.sorted(by: {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                })
                ForEach(appsInFolder) { app in
                    Button(action: {
                        self.excludeList.append(app.bundleID)
                    }, label: {
                        // Resizing the image with SwiftUI did not work.  Therefore we change the size of the NSImage.
                        Image(nsImage: app.icon.resized(to: NSSize(width: 16.0, height: 16.0)))
                        Text(app.displayName)
                    })
                }
            }
        }
    }
}
