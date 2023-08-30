//
//  NSApplication+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-08-20.
//
// From https://github.com/Wouter01/SwiftUI-WindowManagement

import SwiftUI

extension NSApplication {
    func openSettings() {
        let eventSource = CGEventSource(stateID: .hidSystemState)
        let keyCommand = CGEvent(keyboardEventSource: eventSource, virtualKey: 0x2B, keyDown: true)
        guard let keyCommand else { return }

        keyCommand.flags = .maskCommand
        let event = NSEvent(cgEvent: keyCommand)
        guard let event else { return }

        NSApp.sendEvent(event)
    }
}
