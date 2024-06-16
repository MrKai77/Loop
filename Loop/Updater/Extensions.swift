//
//  Extensions.swift
//  Loop
//
//  Created by Kami on 5/6/2024.
//

import AppKit
import Foundation
import OSLog
import SwiftUI

extension Bundle {
  var name: String {
    string(forInfoDictionaryKey: "CFBundleDisplayName")
      ?? string(forInfoDictionaryKey: "CFBundleName")
      ?? "N/A"
  }

  var version: String {
    infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
  }

  var buildVersion: String {
    infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
  }

  private func string(forInfoDictionaryKey key: String) -> String? {
    object(forInfoDictionaryKey: key) as? String
  }
}

func relaunchApp(afterDelay seconds: TimeInterval = 0.5) -> Never {
  let task = Process()
  task.launchPath = "/bin/sh"
  task.arguments = ["-c", "sleep \(seconds); open \"\(Bundle.main.bundlePath)\""]
  task.launch()
  NSApp.terminate(nil)
  exit(0)
}

extension Int {
  var daysToSeconds: Double { Double(self) * 86_400 }
}

func printOS(_ items: Any..., separator: String = " ", terminator: String = "\n") {
  os_log("%@", log: .default, type: .default, items.map { "\($0)" }.joined(separator: separator))
}

func updateOnMain(after delay: Double? = nil, _ updates: @escaping () -> Void) {
  let executeUpdate = { DispatchQueue.main.async(execute: updates) }
  if let delay = delay {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: executeUpdate)
  } else {
    executeUpdate()
  }
}

func updateOnBackground(_ updates: @escaping () -> Void) {
  DispatchQueue.global(qos: .userInitiated).async(execute: updates)
}

func checkAppDirectoryAndUserRole(
  completion: @escaping ((isInCorrectDirectory: Bool, isAdmin: Bool)) -> Void
) {
  isCurrentUserAdmin { isAdmin in
    let bundlePath = Bundle.main.bundlePath as NSString
    let applicationsDir = "/Applications"
    let userApplicationsDir = "\(NSHomeDirectory())/Applications"
    let isInCorrectDirectory =
      isAdmin
      ? [applicationsDir, userApplicationsDir].contains(bundlePath.deletingLastPathComponent)
      : bundlePath.deletingLastPathComponent == userApplicationsDir
    completion((isInCorrectDirectory, isAdmin))
  }
}

func isCurrentUserAdmin(completion: @escaping (Bool) -> Void) {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/bin/zsh")
  process.arguments = ["-c", "groups $(whoami) | grep -q ' admin '"]
  process.terminationHandler = { completion($0.terminationStatus == 0) }
  try? process.run()
}

func killApp(appId: String, completion: @escaping () -> Void = {}) {
  NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == appId })?.terminate()
  completion()
}

func ensureApplicationSupportFolderExists(appState: AppState) {
  let fileManager = FileManager.default
  let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    .appendingPathComponent("com.kami.developmental-tests")
  if !fileManager.fileExists(atPath: supportURL.path) {
    try? fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)
    printOS("Created Application Support folder")
  }
}
