//
//  multi_audio_outApp.swift
//  Duophonic
//
//  Created by Juri Beforth on 01.12.25.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon and run as an accessory app (menu bar only)
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct Duophonic: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Provide a single shared AppState instance for the app
    private let appState = AppState()
    var body: some Scene {
        // Requires macOS 14+
        // Use a custom image asset for the menu bar icon. Create an image set named
        // "StatusBarIcon" inside Assets.xcassets (preferably a template/monochrome 18pt).
        // Note: the special AppIcon app icon set (AppIcon.appiconset) isn't directly
        // loadable by `Image("...")`, so create a separate image set for the status bar.
        MenuBarExtra {
            ContentView()
                .frame(width: 260)
                .environmentObject(appState)  // inject AppState into the environment
        } label: {
            Image("StatusBarIcon")
                .renderingMode(.template) // allow system tinting for light/dark
        }
        .menuBarExtraStyle(.window)  // try .menu or .window to change appearance
    }
}
