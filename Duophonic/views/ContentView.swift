//
//  ContentView.swift
//  Duophonic
//
//  Created by Juri Beforth on 01.12.25.
//

import SwiftUI

struct ContentView: View {
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            MainView(openSettings: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                    showingSettings = true
                }
            })
            .rotation3DEffect(
                .degrees(showingSettings ? 180 : 0),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.8
            )
            .opacity(showingSettings ? 0 : 1)
            .zIndex(showingSettings ? 0 : 1)
            .allowsHitTesting(!showingSettings)

            SettingsView(onClose: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                    showingSettings = false
                }
            })
            .rotation3DEffect(
                .degrees(showingSettings ? 0 : -180),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                perspective: 0.8
            )
            .opacity(showingSettings ? 1 : 0)
            .zIndex(showingSettings ? 1 : 0)
            .allowsHitTesting(showingSettings)
        }
        .compositingGroup()
        .onAppear {
            // Reset settings panel state when the menu reappears
            showingSettings = false
        }
        .onDisappear {
            // Ensure settings panel is closed when the menu loses focus / the view disappears
            showingSettings = false
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 260)
        .environmentObject(AppState())
}
