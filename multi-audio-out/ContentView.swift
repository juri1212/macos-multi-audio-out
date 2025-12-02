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
        // Use a clear background for the overall view so the window looks like Control Center
        VStack(spacing: 12) {
            // Header container (title + toggle)
            HStack {
                Text("Multi Audio Output")
                    .font(.headline)
                Spacer()
                Toggle(isOn: Binding(get: {
                    audioManager.aggregateEnabled
                }, set: { newValue in
                    if newValue {
                        guard let p = selectedPrimary, let s = selectedSecondary, p != s else {
                            print("Cannot enable aggregate: invalid device selection")
                            return
                        }
                        audioManager.enableAggregate(primary: p, secondary: s)
                        audioManager.refreshDevices()
                    } else {
                        audioManager.disableAggregate()
                    }
                })){}
                .toggleStyle(SwitchToggleStyle())
                .help("Toggle multi-output aggregate device")
                .disabled({
                    // Allow turning off when enabled; require valid selection to turn on
                    if audioManager.aggregateEnabled { return false }
                    guard let p = selectedPrimary, let s = selectedSecondary else { return true }
                    return p == s
                }())
            }
            .controlCenterContainer()

            // Device pickers - present primary and secondary as two separate containers
            let deviceOptions = audioManager.outputDevices.filter { !$0.isAggregate }

            VStack(spacing: 8) {
                // Primary picker + its volume
                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: $selectedPrimary) {
                        ForEach(deviceOptions) { dev in
                            Text(dev.name).tag(Optional(dev))
                        }
                    }
                    .labelsHidden()

                    HStack(spacing: 8) {
                        if selectedPrimary != nil {
                            Image(systemName: volumeIconName(volume: primaryVolume, hasControl: audioManager.deviceHasVolumeControl(selectedPrimary!.id)))
                                .frame(width: 22, height: 22, alignment: .center)
                                .foregroundStyle(selectedPrimary == nil ? .secondary : .primary)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "speaker.slash.fill")
                                .frame(width: 22, height: 22, alignment: .center)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
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
                    }
                }
                .controlCenterContainer()

                // Secondary picker + its volume
                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: $selectedSecondary) {
                        ForEach(deviceOptions) { dev in
                            Text(dev.name).tag(Optional(dev))
                        }
                    }
                    .labelsHidden()

                    HStack(spacing: 8) {
                        if selectedSecondary != nil {
                            Image(systemName: volumeIconName(volume: secondaryVolume, hasControl: audioManager.deviceHasVolumeControl(selectedSecondary!.id)))
                                .frame(width: 22, height: 22, alignment: .center)
                                .foregroundStyle(selectedSecondary == nil ? .secondary : .primary)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "speaker.slash.fill")
                                .frame(width: 22, height: 22, alignment: .center)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
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
                .controlCenterContainer()
            }

            // Footer container with status and actions
            HStack {
                if !audioManager.statusMessage.isEmpty {
                    Text(audioManager.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer()
                Button {
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
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .imageScale(.medium)
                }
                .help("Refresh device list")
                Button("Quit") {
                    // Ensure we reset audio before quitting
                    audioManager.disableAggregate()
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .controlCenterContainer()

        }
        .padding(14)
        .background(Color.clear)
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
        .onChange(of: selectedPrimary) { loadVolumesForSelectedDevices() }
        .onChange(of: selectedSecondary) { loadVolumesForSelectedDevices() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            // Disable aggregate and restore defaults on app quit
            audioManager.disableAggregate()
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

    // Helper: select an SF Symbol based on volume level and whether the device supports volume control
    private func volumeIconName(volume: Double, hasControl: Bool) -> String {
        guard hasControl else { return "speaker.slash.fill" }
        if volume <= 0.0001 { return "speaker.slash.fill" }
        switch volume {
        case 0..<0.33: return "speaker.wave.1.fill"
        case 0.33..<0.66: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }
}

// Small view modifier to create a Control Center / liquid glass style container
private extension View {
    func controlCenterContainer() -> some View {
        self
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06))
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 6)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().frame(width: 260)
    }
}
#endif
