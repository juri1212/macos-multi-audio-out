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
            // Main content
            if !showingSettings {
                MainView(openSettings: {
                    showingSettings = true
                })
                    .transition(
                        .asymmetric(
                            insertion: .identity,
                            removal: .scale.combined(with: .opacity)
                        )
                    )
                    .rotation3DEffect(
                        .degrees(showingSettings ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }

            // Settings content
            if showingSettings {
                SettingsView(onClose: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8))
                    {
                        showingSettings = false
                    }
                })
                .transition(.opacity)
                .rotation3DEffect(
                    .degrees(showingSettings ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
            }
        }
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
