//
//  WindowActionIndicator.swift
//  Loop
//
//  Created by Kai Azim on 2026-01-19.
//

import Foundation

protocol WindowActionIndicator {
    func open(context: ResizeContext)
    func close()
}
