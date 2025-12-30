//
//  View+Extensions.swift
//  Loop
//
//  Created by Kai Azim on 2023-06-14.
//

import SwiftUI

extension View {
    @inlinable
    @ViewBuilder
    func onChange<V>(
        of value: V,
        initial: Bool,
        action: @escaping () -> Void
    ) -> some View where V: Equatable {
        if initial {
            self
                .onChange(of: value) { _ in
                    action()
                }
                .onAppear {
                    action()
                }
        } else {
            self
                .onChange(of: value) { _ in
                    action()
                }
        }
    }
    
    @inlinable
    @ViewBuilder
    func onChange<V>(
        of value: V,
        initial: Bool,
        action: @escaping (V) -> Void
    ) -> some View where V: Equatable {
        if initial {
            self
                .onChange(of: value) { newValue in
                    action(newValue)
                }
                .onAppear {
                    action(value)
                }
        } else {
            self
                .onChange(of: value) { newValue in
                    action(newValue)
                }
        }
    }
}
