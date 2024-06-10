//
//  View+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import SwiftUI

extension View {
    // Make it easier to receive notifications SwiftUI views
    func onReceive(
        _ name: Notification.Name,
        center: NotificationCenter = .default,
        object: AnyObject? = nil,
        perform action: @escaping (Notification) -> ()
    ) -> some View {
        onReceive(
            center.publisher(for: name, object: object),
            perform: action
        )
    }
}
