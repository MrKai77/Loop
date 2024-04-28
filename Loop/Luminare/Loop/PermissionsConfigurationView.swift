//
//  PermissionsConfigurationView.swift
//  Loop
//
//  Created by Kai Azim on 2024-04-26.
//

import SwiftUI
import Luminare
import Defaults

struct PermissionsConfigurationView: View {
    @Default(.animateWindowResizes) var animateWindowResizes

    @State var isAccessibilityAccessGranted = false
    @State var isScreenCaptureAccessGranted = false

    let elementHeight: CGFloat = 34

    var body: some View {
        LuminareSection {
            HStack {
                if isAccessibilityAccessGranted {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green.pastelized)
                }

                Text("Accessibility access")

                Spacer()

                Button {
                    withAnimation(.smooth) {
                        isAccessibilityAccessGranted = PermissionsManager.accessibility.requestAccess()
                    }
                } label: {
                    Text("Request…")
                        .frame(height: 30)
                        .padding(.horizontal, 8)
                }
                .disabled(isAccessibilityAccessGranted)
                .buttonStyle(LuminareCompactButtonStyle(extraCompact: true))
            }
            .padding(.leading, 12)
            .padding(.trailing, 2)
            .frame(height: elementHeight)

            HStack {
                if isScreenCaptureAccessGranted {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green.pastelized)
                }

                Text("Screen capture access")

                Spacer()

                Button {
                    withAnimation(.smooth) {
                        isScreenCaptureAccessGranted = PermissionsManager.screenCapture.requestAccess()
                    }
                } label: {
                    Text("Request…")
                        .frame(height: 30)
                        .padding(.horizontal, 8)
                }
                .disabled(isScreenCaptureAccessGranted)
                .buttonStyle(LuminareCompactButtonStyle(extraCompact: true))
            }
            .padding(.leading, 12)
            .padding(.trailing, 2)
            .frame(height: elementHeight)
        }
        .onAppear {
            isAccessibilityAccessGranted = PermissionsManager.accessibility.getStatus()
            isScreenCaptureAccessGranted = PermissionsManager.screenCapture.getStatus()

            if !isScreenCaptureAccessGranted {
                self.animateWindowResizes = false
            }
        }
    }
}
