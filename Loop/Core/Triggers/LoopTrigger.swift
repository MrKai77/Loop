//
//  LoopTrigger.swift
//  Loop
//
//  Created by Kai Azim on 2025-09-06.
//

import Foundation

protocol LoopTrigger {
    init(
        openCallback: @escaping (WindowAction?) -> (),
        closeCallback: @escaping () -> ()
    )

    func start()
    func stop()
}
