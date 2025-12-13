//
//  MainView.swift
//  Duophonic
//
//  Created by Juri Beforth on 13.12.25.
//

import SwiftUI

struct MainView: View {
    @StateObject private var audioManager = AudioAggregateManager()
    @State private var selectedPrimary: AudioDeviceInfo? = nil
    @State private var selectedSecondary: AudioDeviceInfo? = nil

    // Per-device volume values (0.0 - 1.0) used by sliders
    @State private var primaryVolume: Double = 1.0
    @State private var secondaryVolume: Double = 1.0

    var body: some View {
        VStack(spacing: 12) {
            // Header container (title + toggle + settings button)
            HStack {
                Text("Multi-Output Device")
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
                    HStack(alignment: .center, spacing: 8) {
                        Picker("", selection: $selectedPrimary) {
                            ForEach(deviceOptions) { dev in
                                Text(dev.name).tag(Optional(dev))
                            }
                            Section("Device not found?") {
                                Text("Refresh the device list using the button below.")
                            }
                        }
                        .labelsHidden()

                        // Refresh button that preserves current selection so an open picker won't be forced closed
                        Button {
                            refreshAudioDevices(preserveSelection: true)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                        .help("Refresh devices")
                    }

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
                    HStack(alignment: .center, spacing: 8) {
                        Picker("", selection: $selectedSecondary) {
                            ForEach(deviceOptions) { dev in
                                Text(dev.name).tag(Optional(dev))
                            }
                        }
                        .labelsHidden()

                        Button {
                            refreshAudioDevices(preserveSelection: true)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                        .help("Refresh devices")
                    }

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
        }
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
    }

    // Refresh devices. When preserveSelection is true, keep the current selection if the device IDs still exist
    private func refreshAudioDevices(preserveSelection: Bool = false) {
        let prevPrimaryID = selectedPrimary?.id
        let prevSecondaryID = selectedSecondary?.id

        audioManager.refreshDevices()

        if !preserveSelection {
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
        } else {
            // Preserve selection: re-bind to the device instances in the refreshed list if they still exist.
            let opts = audioManager.outputDevices
            if let pid = prevPrimaryID {
                selectedPrimary = opts.first(where: { $0.id == pid })
            }
            if let sid = prevSecondaryID {
                selectedSecondary = opts.first(where: { $0.id == sid })
            }
            // Do not auto-select new devices when preserving.
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

#Preview {
    MainView()
        .frame(width: 260 - 2 * 14)
        .padding(14)
}
