//
//  ContentView.swift
//  multi-audio-out
//
//  Created by Juri Beforth on 01.12.25.
//
import SwiftUI

struct ContentView: View {
    @State private var count = 0
    @State private var showPreferences = false
    @State private var toggleOn = false

    @StateObject private var audioManager = AudioAggregateManager()
    @State private var selectedPrimary: AudioDeviceInfo? = nil
    @State private var selectedSecondary: AudioDeviceInfo? = nil

    var body: some View {
        VStack(spacing: 12) {
            Text("Multi-Output Audio")
                .font(.headline)

            // Device pickers
            let deviceOptions = audioManager.outputDevices.filter { !$0.isAggregate }

            VStack(alignment: .leading, spacing: 8) {
                Text("Choose two different output devices:")
                    .font(.subheadline)
                Picker("Primary device", selection: $selectedPrimary) {
                    ForEach(deviceOptions) { dev in
                        Text(dev.name).tag(Optional(dev))
                    }
                }
                Picker("Secondary device", selection: $selectedSecondary) {
                    ForEach(deviceOptions) { dev in
                        Text(dev.name).tag(Optional(dev))
                    }
                }
            }

            HStack(spacing: 8) {
                Button(audioManager.aggregateEnabled ? "Disable Multi-Output" : "Enable Multi-Output") {
                    if audioManager.aggregateEnabled {
                        audioManager.disableAggregate()
                    } else if let p = selectedPrimary, let s = selectedSecondary {
                        audioManager.enableAggregate(primary: p, secondary: s)
                        audioManager.refreshDevices()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled({
                    if audioManager.aggregateEnabled { return false }
                    guard let p = selectedPrimary, let s = selectedSecondary else { return true }
                    return p == s
                }())

                Button("Refresh Devices") {
                    audioManager.refreshDevices()
                    // Attempt to auto-select first two devices if nothing chosen
                    if selectedPrimary == nil || selectedSecondary == nil {
                        let opts = audioManager.outputDevices.filter { !$0.isAggregate }
                        if opts.count >= 2 {
                            selectedPrimary = opts[0]
                            selectedSecondary = opts[1]
                        } else if opts.count == 1 {
                            selectedPrimary = opts[0]
                            selectedSecondary = nil
                        } else {
                            selectedPrimary = nil
                            selectedSecondary = nil
                        }
                    }
                }
            }

            if !audioManager.statusMessage.isEmpty {
                Text(audioManager.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Divider()

            HStack {
                Button("Preferences") { showPreferences = true }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding()
        .onAppear {
            // Preselect first two non-aggregate outputs if available
            let opts = audioManager.outputDevices.filter { !$0.isAggregate }
            if opts.count >= 2 {
                selectedPrimary = opts[0]
                selectedSecondary = opts[1]
            } else if opts.count == 1 {
                selectedPrimary = opts[0]
                selectedSecondary = nil
            }
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesView(toggleOn: $toggleOn)
                .frame(minWidth: 320, minHeight: 140)
        }
    }
}

struct PreferencesView: View {
    @Binding var toggleOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.title2)
            Toggle("Enable option", isOn: $toggleOn)
            Spacer()
            HStack {
                Spacer()
                Button("Done") { NSApp.keyWindow?.close() }
            }
        }
        .padding()
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().frame(width: 260)
    }
}
#endif
