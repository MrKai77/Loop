//
//  WindowDragView.swift
//  Loop
//
//  Created by Kyan De Sutter on 25/7/24.
//

import SwiftUI

struct WindowDragView: View {
    var body: some View {
        HStack(spacing: 10) {
            MouseTrackingRectangle(rectIdentifier: "Rectangle 1")
                .frame(width: 80, height: 120)
            MouseTrackingRectangle(rectIdentifier: "Rectangle 2")
                .frame(width: 80, height: 120)
            MouseTrackingRectangle(rectIdentifier: "Rectangle 3")
                .frame(width: 80, height: 120)
            VStack(spacing: 10) {
                MouseTrackingRectangle(rectIdentifier: "Rectangle 4")
                    .frame(width: 80, height: 55)
                MouseTrackingRectangle(rectIdentifier: "Rectangle 5")
                    .frame(width: 80, height: 55)
            }
        }
        .padding(10)
    }
}

struct MouseTrackingRectangle: NSViewRepresentable {
    var rectIdentifier: String
    
    func makeNSView(context: Context) -> CustomNSView {
        let nsView = CustomNSView(rectIdentifier: rectIdentifier)
        nsView.wantsLayer = true
        nsView.layer?.backgroundColor = NSColor.gray.cgColor
        return nsView
    }
    
    func updateNSView(_ nsView: CustomNSView, context: Context) {
        // No need to update anything in this example
    }
}

class CustomNSView: NSView {
    var rectIdentifier: String
    private var eventMonitor: Any?
    
    init(rectIdentifier: String) {
        self.rectIdentifier = rectIdentifier
        super.init(frame: .zero)
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            guard let self = self else { return }
            let mouseLocation = NSEvent.mouseLocation
            let convertedMouseLocation = self.window?.convertPoint(fromScreen: mouseLocation) ?? .zero
            let localPoint = self.convert(convertedMouseLocation, from: nil)
            
            if self.bounds.contains(localPoint) {
                print("Released in \(self.rectIdentifier)")
                if self.rectIdentifier == "Rectangle 0"{
                    // implement this
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in trackingAreas {
            self.removeTrackingArea(trackingArea)
        }
        let trackingArea = NSTrackingArea(rect: self.bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    
    deinit {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        WindowDragView()
    }
}
