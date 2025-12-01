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

    // Per-device volume values (0.0 - 1.0) used by sliders
    @State private var primaryVolume: Double = 1.0
    @State private var secondaryVolume: Double = 1.0

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

                // Volume controls for selected devices
                Group {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Primary Volume")
                                .font(.caption)
                            Text(selectedPrimary?.name ?? "No device selected")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(primaryVolume * 100))%")
                            .frame(width: 50, alignment: .trailing)
                    }
                    Slider(value: Binding(get: {
                        primaryVolume
                    }, set: { new in
                        primaryVolume = new
                        if let dev = selectedPrimary {
                            _ = audioManager.setDeviceVolume(dev.id, value: Float(new))
                        }
                    }), in: 0...1)
                    .disabled(selectedPrimary == nil || (selectedPrimary != nil && !audioManager.deviceHasVolumeControl(selectedPrimary!.id)))

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Secondary Volume")
                                .font(.caption)
                            Text(selectedSecondary?.name ?? "No device selected")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(secondaryVolume * 100))%")
                            .frame(width: 50, alignment: .trailing)
                    }
                    Slider(value: Binding(get: {
                        secondaryVolume
                    }, set: { new in
                        secondaryVolume = new
                        if let dev = selectedSecondary {
                            _ = audioManager.setDeviceVolume(dev.id, value: Float(new))
                        }
                    }), in: 0...1)
                    .disabled(selectedSecondary == nil || (selectedSecondary != nil && !audioManager.deviceHasVolumeControl(selectedSecondary!.id)))
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
                            loadVolumesForSelectedDevices()
                        } else if opts.count == 1 {
                            selectedPrimary = opts[0]
                            selectedSecondary = nil
                            loadVolumesForSelectedDevices()
                        } else {
                            selectedPrimary = nil
                            selectedSecondary = nil
                            loadVolumesForSelectedDevices()
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
                loadVolumesForSelectedDevices()
            } else if opts.count == 1 {
                selectedPrimary = opts[0]
                selectedSecondary = nil
                loadVolumesForSelectedDevices()
            }
        }
        .onChange(of: selectedPrimary) { _ in loadVolumesForSelectedDevices() }
        .onChange(of: selectedSecondary) { _ in loadVolumesForSelectedDevices() }
        .sheet(isPresented: $showPreferences) {
            PreferencesView(toggleOn: $toggleOn)
                .frame(minWidth: 320, minHeight: 140)
        }
    }

    // Load volumes from AudioAggregateManager for the currently selected devices
    private func loadVolumesForSelectedDevices() {
        if let p = selectedPrimary {
            if let v = audioManager.getDeviceVolume(p.id) {
                primaryVolume = Double(v)
            } else {
                primaryVolume = 1.0
            }
        } else {
            primaryVolume = 1.0
        }

        if let s = selectedSecondary {
            if let v = audioManager.getDeviceVolume(s.id) {
                secondaryVolume = Double(v)
            } else {
                secondaryVolume = 1.0
            }
        } else {
            secondaryVolume = 1.0
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
