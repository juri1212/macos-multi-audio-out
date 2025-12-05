//
//  ContentView.swift
//  multi-audio-out
//
//  Created by Juri Beforth on 01.12.25.
//

import Combine
import ServiceManagement
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
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            // Main content
            if !showingSettings {
                VStack(spacing: 12) {
                    // Header container (title + toggle + settings button)
                    HStack {
                        Text("Multi Audio Output")
                            .font(.headline)
                        Spacer()
                        Toggle(
                            isOn: Binding(
                                get: {
                                    audioManager.aggregateEnabled
                                },
                                set: { newValue in
                                    if newValue {
                                        guard let p = selectedPrimary,
                                            let s = selectedSecondary, p != s
                                        else {
                                            audioManager.setStatusMessage(
                                                "Cannot enable aggregate: invalid device selection"
                                            )
                                            return
                                        }
                                        audioManager.enableAggregate(
                                            primary: p,
                                            secondary: s
                                        )
                                        audioManager.refreshDevices()
                                    } else {
                                        audioManager.disableAggregate()
                                    }
                                }
                            )
                        ) {}
                        .toggleStyle(SwitchToggleStyle())
                        .help("Toggle multi-output aggregate device")
                        .disabled(
                            {
                                // Allow turning off when enabled; require valid selection to turn on
                                if audioManager.aggregateEnabled {
                                    return false
                                }
                                guard let p = selectedPrimary,
                                    let s = selectedSecondary
                                else { return true }
                                return p == s
                            }()
                        )
                    }
                    .controlCenterContainer()

                    let deviceOptions = audioManager.outputDevices.filter {
                        !$0.isAggregate
                    }

                    VStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("", selection: $selectedPrimary) {
                                ForEach(deviceOptions) { dev in
                                    Text(dev.name).tag(Optional(dev))
                                }
                            }
                            .labelsHidden()

                            HStack(spacing: 8) {
                                if selectedPrimary != nil {
                                    Image(
                                        systemName: volumeIconName(
                                            volume: primaryVolume,
                                            hasControl:
                                                audioManager
                                                .deviceHasVolumeControl(
                                                    selectedPrimary!.id
                                                )
                                        )
                                    )
                                    .frame(
                                        width: 22,
                                        height: 22,
                                        alignment: .center
                                    )
                                    .foregroundStyle(
                                        selectedPrimary == nil
                                            ? .secondary : .primary
                                    )
                                    .accessibilityHidden(true)
                                } else {
                                    Image(systemName: "speaker.slash.fill")
                                        .frame(
                                            width: 22,
                                            height: 22,
                                            alignment: .center
                                        )
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)
                                }

                                Slider(
                                    value: Binding(
                                        get: {
                                            primaryVolume
                                        },
                                        set: { new in
                                            primaryVolume = new
                                            if let dev = selectedPrimary {
                                                _ =
                                                    audioManager.setDeviceVolume(
                                                        dev.id,
                                                        value: Float(new)
                                                    )
                                            }
                                        }
                                    ),
                                    in: 0...1
                                )
                                .disabled(
                                    selectedPrimary == nil
                                        || (selectedPrimary != nil
                                            && !audioManager
                                                .deviceHasVolumeControl(
                                                    selectedPrimary!.id
                                                ))
                                )
                            }
                        }
                        .controlCenterContainer()

                        VStack(alignment: .leading, spacing: 8) {
                            Picker("", selection: $selectedSecondary) {
                                ForEach(deviceOptions) { dev in
                                    Text(dev.name).tag(Optional(dev))
                                }
                            }
                            .labelsHidden()

                            HStack(spacing: 8) {
                                if selectedSecondary != nil {
                                    Image(
                                        systemName: volumeIconName(
                                            volume: secondaryVolume,
                                            hasControl:
                                                audioManager
                                                .deviceHasVolumeControl(
                                                    selectedSecondary!.id
                                                )
                                        )
                                    )
                                    .frame(
                                        width: 22,
                                        height: 22,
                                        alignment: .center
                                    )
                                    .foregroundStyle(
                                        selectedSecondary == nil
                                            ? .secondary : .primary
                                    )
                                    .accessibilityHidden(true)
                                } else {
                                    Image(systemName: "speaker.slash.fill")
                                        .frame(
                                            width: 22,
                                            height: 22,
                                            alignment: .center
                                        )
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)
                                }

                                Slider(
                                    value: Binding(
                                        get: {
                                            secondaryVolume
                                        },
                                        set: { new in
                                            secondaryVolume = new
                                            if let dev = selectedSecondary {
                                                _ =
                                                    audioManager.setDeviceVolume(
                                                        dev.id,
                                                        value: Float(new)
                                                    )
                                            }
                                        }
                                    ),
                                    in: 0...1
                                )
                                .disabled(
                                    selectedSecondary == nil
                                        || (selectedSecondary != nil
                                            && !audioManager
                                                .deviceHasVolumeControl(
                                                    selectedSecondary!.id
                                                ))
                                )
                            }
                        }
                        .controlCenterContainer()
                    }

                    HStack {
                        if !audioManager.statusMessage.isEmpty {
                            Text(audioManager.statusMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        Button {
                            withAnimation(
                                .spring(response: 0.5, dampingFraction: 0.8)
                            ) {
                                showingSettings = true
                            }
                        } label: {
                            Image(systemName: "gearshape")
                                .imageScale(.medium)
                        }
                        .help("Open Settings")
                        .buttonStyle(.plain)
                        Spacer()
                        Button {
                            refreshAudioDevices()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .imageScale(.medium)
                        }
                        .help("Refresh device list")
                        .buttonStyle(.plain)
                        Button("Quit") {
                            // Ensure we reset audio before quitting
                            audioManager.disableAggregate()
                            NSApp.terminate(nil)
                        }
                        .keyboardShortcut("q", modifiers: .command)
                        .buttonStyle(.plain)
                    }
                    .controlCenterContainer()

                }
                .padding(14)
                .background(Color.clear)
                .onAppear {
                    refreshAudioDevices()
                }
                .onChange(of: selectedPrimary) {
                    loadVolumesForSelectedDevices()
                }
                .onChange(of: selectedSecondary) {
                    loadVolumesForSelectedDevices()
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.willTerminateNotification
                    )
                ) { _ in
                    // Disable aggregate and restore defaults on app quit
                    audioManager.disableAggregate()
                }
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

    private func refreshAudioDevices() {
        audioManager.refreshDevices()

        if let subs = audioManager.readLiveAggregateSubDevices() {
            selectedPrimary = subs.primaryDevice
            selectedSecondary = subs.secondaryDevice
        }

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
        loadVolumesForSelectedDevices()
    }

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
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8))
                    {
                        onClose()
                    }
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

extension View {
    fileprivate func controlCenterContainer() -> some View {
        self
            .padding(12)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06))
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 6)
    }
}

// Replace @Observable macro with classic ObservableObject for compatibility
class AppState: ObservableObject {
    @Published var launchAtLogin = false
}

#if DEBUG
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
                .frame(width: 260)
                .environmentObject(AppState())
        }
    }
#endif
