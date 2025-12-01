//
//  multi_audio_outApp.swift
//  multi-audio-out
//
//  Created by Juri Beforth on 01.12.25.
//

import SwiftUI

@main
struct multi_audio_outApp: App {
    var body: some Scene {
            // Requires macOS 14+
            MenuBarExtra("MyMenuApp", systemImage: "star.fill") {
                ContentView()
                    .frame(width: 260)
            }
            .menuBarExtraStyle(.window) // try .menu or .window to change appearance
        }
}
