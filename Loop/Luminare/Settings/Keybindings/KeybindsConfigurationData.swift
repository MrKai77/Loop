//
//  KeybindsConfigurationData.swift
//  Loop
//
//  Created by Kai Azim on 2023-11-24.
//

import SwiftUI

class KeybindsConfigurationData: ObservableObject {
    @Published var eventMonitor: NSEventMonitor?
    @Published var selectedKeybinds: Set<WindowAction> = []
}
