//
//  multi_audio_outApp.swift
//  multi-audio-out
//
//  Created by Juri Beforth on 01.12.25.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon and run as an accessory app (menu bar only)
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct multi_audio_outApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
            // Requires macOS 14+
            MenuBarExtra("MyMenuApp", systemImage: "headphones") {
                ContentView()
                    .frame(width: 260)
            }
            .menuBarExtraStyle(.window) // try .menu or .window to change appearance
        }
}
