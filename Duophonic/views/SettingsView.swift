//
//  SettingsView.swift
//  Duophonic
//
//  Created by Juri Beforth on 13.12.25.
//

import ServiceManagement
import SwiftUI

struct SettingsView: View {
    // Use EnvironmentObject to receive the appState injected in the App entrypoint
    @EnvironmentObject var appState: AppState
    @State private var placeholderToggle = false

    var body: some View {
        VStack(spacing: 12) {
            // Use the label closure so we can add spacing between the label and the toggle control
            Toggle(isOn: $appState.launchAtLogin) {
                HStack {
                    Text("Start on login")
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
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

            Spacer()

            HStack {
                // GitHub link — replace the URL with your GitHub repo URL
                if let githubURL = URL(string: "https://github.com/juri1212/Duophonic") {
                    Link(destination: githubURL) {
                        Image(systemName: "chevron.left.slash.chevron.right")
                            .imageScale(.large)
                        Text("GitHub").font(.footnote)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Duophonic on GitHub")
                    .accessibilityAddTraits(.isLink)
                    .help("Open Duophonic on GitHub")
                }
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power").imageScale(.large)
                }
                .keyboardShortcut("q", modifiers: .command)
                .buttonStyle(.plain)
                .help("Quit Duophonic")
            }.controlCenterContainer()
            Text(
                "Duophonic v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?.?.?")"
            )
            .font(.footnote)

        }
        .background(Color.clear)

    }
}

#Preview {
    SettingsView()
        .frame(width: 260 - 2 * 14)
        .padding(14)
        .environmentObject(AppState())
}
