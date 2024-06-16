//
//  NewWin.swift
//  Loop
//
//  Created by Kami on 5/6/2024.
//

import AppKit
import SwiftUI

class NewWin: NSWindowController {
  static let shared = NewWin()

  static func show(appState: AppState, width: CGFloat, height: CGFloat, newWin: NewWindow) {
    if shared.window == nil {
      shared.window = Self.makeWindow(width: width, height: height)
      setupWindow(window: shared.window, appState: appState, newWin: newWin)
    }
    shared.window?.makeKeyAndOrderFront(nil)
  }

  static func close() {
    shared.window?.close()
  }

  private static func setupWindow(window: NSWindow?, appState: AppState, newWin: NewWindow) {
    guard let window = window else { return }

    window.backgroundColor = NSColor.controlBackgroundColor
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.center()
    window.title = "Loop"

    let visualEffect = NSVisualEffectView(frame: window.contentRect(forFrameRect: window.frame))
    visualEffect.blendingMode = .behindWindow
    visualEffect.state = .active
    visualEffect.material = .underWindowBackground
    window.contentView = visualEffect

    let contentView = makeNewView(appState: appState, newWin: newWin)
    let hostView = NSHostingView(rootView: contentView)
    visualEffect.addSubview(hostView)
    hostView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hostView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
      hostView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
      hostView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
      hostView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
    ])
  }

  private static func makeWindow(width: CGFloat, height: CGFloat) -> NSWindow {
    let contentRect = NSRect(x: 0, y: 0, width: width, height: height)
    let styleMask: NSWindow.StyleMask = [.titled, .fullSizeContentView]
    return NSWindow(
      contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
  }

  private static func makeNewView(appState: AppState, newWin: NewWindow) -> some View {
    let view: AnyView
    switch newWin {
    case .update:
      view = AnyView(UpdateView().environmentObject(appState))
    case .no_update:
      view = AnyView(NoUpdateView().environmentObject(appState))
    }
    return view.frame(maxWidth: .infinity, maxHeight: .infinity).background(
      Color.black.opacity(0.2))
  }
}
