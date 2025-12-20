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
        VStack {
            HStack {
                Text(showingSettings ? "Settings" : "Duophonic")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(
                        .spring(response: 0.5, dampingFraction: 0.8)
                    ) {
                        withAnimation(
                            .spring(response: 0.6, dampingFraction: 0.9)
                        ) {
                            showingSettings.toggle()
                        }
                    }
                } label: {
                    Image(
                        systemName: showingSettings
                            ? "xmark.circle.fill" : "gearshape"
                    )
                    .imageScale(.large)
                }
                .help(showingSettings ? "Close Settings" : "Open Settings")
                .buttonStyle(.plain)
            }.padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 0)
            Divider().padding(0)
            Spacer().frame(height: 16)
            ZStack(alignment: .top) {
                MainView(settingsShowing: $showingSettings)
                    .rotation3DEffect(
                        .degrees(showingSettings ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .center,
                        perspective: 0.8
                    )
                    .opacity(showingSettings ? 0 : 1)
                    .zIndex(showingSettings ? 0 : 1)
                    .allowsHitTesting(!showingSettings)

                SettingsView()
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
                showingSettings = false
            }
        }.padding(0)
    }
}

#Preview {
    ContentView()
        .frame(width: 260)
        .environmentObject(AppState())
}
