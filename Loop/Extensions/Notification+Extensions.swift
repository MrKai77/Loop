//
//  Notification+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import Foundation

extension Notification.Name {
    static let updateBackendDirection = Notification.Name("updateBackendDirection")
    static let updateUIDirection = Notification.Name("updateUIDirection")

    static let forceCloseLoop = Notification.Name("forceCloseLoop")
    static let didLoop = Notification.Name("didLoop")

    @discardableResult
    func onReceive(object: Any? = nil, using: @escaping (Notification) -> Void) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(
            forName: self,
            object: object,
            queue: .main,
            using: using
        )
    }

    func post(object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        NotificationCenter.default.post(name: self, object: object, userInfo: userInfo)
    }
}
