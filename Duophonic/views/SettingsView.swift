//
//  SettingsView.swift
//  Duophonic
//
//  Created by Juri Beforth on 13.12.25.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    // Use EnvironmentObject to receive the appState injected in the App entrypoint
    @EnvironmentObject var appState: AppState
    var onClose: () -> Void
    @State private var placeholderToggle = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.medium)
                }
                .help("Close Settings")
                .buttonStyle(.plain)
            }
            .controlCenterContainer()

            Toggle("Start on login", isOn: $appState.launchAtLogin)
                .toggleStyle(SwitchToggleStyle())
                .onChange(of: appState.launchAtLogin) { _, newValue in
                    if newValue == true {
                        try? SMAppService.mainApp.register()
                    } else {
                        try? SMAppService.mainApp.unregister()
                    }
                }
                .onAppear {
                    if SMAppService.mainApp.status == .enabled {
                        appState.launchAtLogin = true
                    } else {
                        appState.launchAtLogin = false
                    }
                }
                .controlCenterContainer()

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.clear)
    }
}

#Preview {
    SettingsView(onClose: {})
        .frame(width: 260)
        .environmentObject(AppState())
}
