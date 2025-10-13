//
//  CustomTextField.swift
//  Loop
//
//  Created by Kai Azim on 2024-08-26.
//

import SwiftUI

// Custom TextField that will allow for auto-focus to happen correctly when the popover is shown.
struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    init(_ text: Binding<String>, _ placeholder: String = .init(localized: "Search for a window action", defaultValue: "Search…")) {
        self._text = text
        self.placeholder = placeholder
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.isBezeled = false
        textField.placeholderString = placeholder
        textField.isEditable = true
        textField.isSelectable = true
        textField.drawsBackground = false
        textField.isBordered = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.focusRingType = .none

        // Set the target-action for text changes
        textField.delegate = context.coordinator

        DispatchQueue.main.async {
            textField.becomeFirstResponder()
        }

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context _: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CustomTextField

        init(_ parent: CustomTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                // Update the binding when the text changes
                parent.text = textField.stringValue
            }
        }
    }
}
