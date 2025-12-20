//
//  MainView.swift
//  Duophonic
//
//  Created by Juri Beforth on 13.12.25.
//

import SwiftUI

struct MainView: View {
    @Binding var settingsShowing: Bool
    @StateObject private var audioManager: AudioAggregateManager
    @StateObject private var primarySelector: AudioDeviceSelectorModel
    @StateObject private var secondarySelector: AudioDeviceSelectorModel

    init(settingsShowing: Binding<Bool> = .constant(false)) {
        _settingsShowing = settingsShowing
        let manager = AudioAggregateManager()
        _audioManager = StateObject(wrappedValue: manager)
        _primarySelector = StateObject(
            wrappedValue: AudioDeviceSelectorModel(
                audioManager: manager,
                isPrimary: true
            )
        )
        _secondarySelector = StateObject(
            wrappedValue: AudioDeviceSelectorModel(
                audioManager: manager,
                isPrimary: false
            )
        )
    }

    var body: some View {
        VStack(spacing: 12) {
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
                                guard
                                    let p = primarySelector.currentDevice?
                                        .audioDeviceInfo,
                                    let s = secondarySelector.currentDevice?
                                        .audioDeviceInfo,
                                    p != s
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
                        if audioManager.aggregateEnabled {
                            return false
                        }
                        guard
                            let p = primarySelector.currentDevice?
                                .audioDeviceInfo,
                            let s = secondarySelector.currentDevice?
                                .audioDeviceInfo
                        else { return true }
                        return p == s
                    }()
                )
            }
            .padding(.horizontal, 16)

            VStack(spacing: 8) {
                AudioDeviceSelectorView(viewModel: primarySelector)
                    .onChange(of: primarySelector.isExpanded) { _, newValue in
                        if newValue {
                            secondarySelector.isExpanded = false
                            audioManager.refreshDevices()
                        }
                    }

                AudioDeviceSelectorView(viewModel: secondarySelector)
                    .onChange(of: secondarySelector.isExpanded) { _, newValue in
                        if newValue {
                            primarySelector.isExpanded = false
                            audioManager.refreshDevices()
                        }
                    }
            }
        }
        .background(Color.clear)
        .onAppear {
            audioManager.refreshDevices()
            initializeDeviceSelectors()
        }
        .onDisappear {
            primarySelector.isExpanded = false
            secondarySelector.isExpanded = false
        }
        .onChange(of: settingsShowing) { _, newValue in
            if newValue {
                primarySelector.isExpanded = false
                secondarySelector.isExpanded = false
            }
        }
    }

    private func initializeDeviceSelectors() {
        if let subs = audioManager.readLiveAggregateSubDevices() {
            audioManager.selectPrimaryDevice(subs.primaryDevice.id)
            audioManager.selectSecondaryDevice(subs.secondaryDevice.id)
        } else {
            let opts = audioManager.outputDevices.filter { !$0.isAggregate }
            if opts.count >= 2 {
                audioManager.selectPrimaryDevice(opts[0].id)
                audioManager.selectSecondaryDevice(opts[1].id)
            } else if opts.count == 1 {
                audioManager.selectPrimaryDevice(opts[0].id)
            }
        }
    }
}

#Preview {
    MainView(settingsShowing: .constant(false))
        .frame(width: 300 - 2 * 14, height: 300)
        .padding(14)
}
