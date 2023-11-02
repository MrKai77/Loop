//
//  KeybindCustomizationView.swift
//  Loop
//
//  Created by Kai Azim on 2023-10-31.
//

import SwiftUI
import Defaults

struct KeybindCustomizationView: View {
    @Default(.keybinds) var keybinds

    var body: some View {
        ScrollView {
                ForEach(self.$keybinds) { keybind in
                    KeybindCustomizationViewItem(keybind: keybind)
                }
        }
        .frame(height: 300)
    }
}

struct KeybindCustomizationViewItem: View {
    let keybind: Binding<Keybind>

    @State var isOpen = false

    init?(keybind: Binding<Keybind>) {
        self.keybind = keybind
    }

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.isOpen.toggle()
                        }
                    }, label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .fontWeight(.bold)
                            .rotationEffect(self.isOpen ? .degrees(90) : .zero)
                    })

                    keybind.direction.wrappedValue.menuBarImage
                    Text(keybind.direction.wrappedValue.name)

                    Spacer()
                    Text("\(keybind.keybind.wrappedValue.description)")
                }
                .fixedSize(horizontal: false, vertical: true)

                ZStack {
                    Rectangle()
                        .foregroundStyle(.clear)

                    Text("Hello World")
                }

                .rotation3DEffect(self.isOpen ? .zero : .degrees(-90), axis: (x: 1, y: 0, z: 0), anchor: .top)
            }
        }
        .padding(8)
        .frame(height: self.isOpen ? 100 : 30)
        .background(.quinary)
        .mask(RoundedRectangle(cornerRadius: 8))
        .background(content: {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quinary, lineWidth: 1)
        })
        .buttonStyle(.plain)
    }
}

#Preview {
    KeybindCustomizationView()
        .frame(width: 350)
        .padding()
}

// FOR REFERENCE
//            Picker("", selection: keybind.direction) {
//                ForEach(WindowDirection.allCases) { direction in
//                    if let image = direction.menuBarImage,
//                       let name = direction.name {
//                        HStack {
//                            image
//                            Text(name)
//                        }
//                        .tag(direction)
//                        .onAppear {
//                            print("TEST")
//                        }
//                    }
//                }
//            }
//            .fixedSize()
//            .padding(.leading, -10)
