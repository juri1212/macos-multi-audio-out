//
//  AudioDeviceControlView.swift
//  Duophonic
//
//  Created by Juri Beforth on 19.12.25.
//

import Combine
import CoreAudio
import SwiftUI

#if canImport(AppKit)
    import AppKit
#endif

@MainActor final class AudioDeviceSelectorModel: ObservableObject {
    @Published var isExpanded = false
    @Published var isRefreshing = false

    let audioManager: AudioAggregateManager
    let isPrimary: Bool
    private var cancellables = Set<AnyCancellable>()

    var devices: [AudioDevice] { audioManager.devices }
    var selectedDeviceID: AudioObjectID? {
        isPrimary
            ? audioManager.primaryDeviceID : audioManager.secondaryDeviceID
    }
    var currentDevice: AudioDevice? {
        isPrimary ? audioManager.primaryDevice : audioManager.secondaryDevice
    }
    var currentVolume: Double { currentDevice?.volume ?? 0.5 }
    var isAudioEnabled: Bool { !audioManager.devices.isEmpty }

    init(audioManager: AudioAggregateManager, isPrimary: Bool) {
        self.audioManager = audioManager
        self.isPrimary = isPrimary

        // Observe changes to the audio manager's published properties
        audioManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    func setVolume(_ value: Double) {
        guard let id = selectedDeviceID,
            let index = audioManager.devices.firstIndex(where: { $0.id == id })
        else { return }
        audioManager.devices[index].volume = value
        _ = audioManager.setDeviceVolume(id, value: Float(value))
    }

    func selectDevice(_ device: AudioDevice) {
        if isPrimary {
            audioManager.selectPrimaryDevice(device.id)
        } else {
            audioManager.selectSecondaryDevice(device.id)
        }
    }

    func refreshDevices() {
        guard !isRefreshing else { return }
        isRefreshing = true
        audioManager.refreshDevices()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.isRefreshing = false
        }
    }

    #if DEBUG
        static var preview: AudioDeviceSelectorModel {
            let manager = AudioAggregateManager()
            manager.devices = [
                AudioDevice(
                    audioDeviceInfo: AudioDeviceInfo(
                        id: 1,
                        uid: "builtin",
                        name: "MacBook Pro Speakers",
                        isOutputCapable: true,
                        isAggregate: false
                    ),
                    category: .builtin,
                    supportsVolume: true,
                    volume: 0.7
                ),
                AudioDevice(
                    audioDeviceInfo: AudioDeviceInfo(
                        id: 2,
                        uid: "airpods",
                        name: "AirPods Pro",
                        isOutputCapable: true,
                        isAggregate: false
                    ),
                    category: .bluetooth,
                    supportsVolume: true,
                    volume: 0.45
                ),
                AudioDevice(
                    audioDeviceInfo: AudioDeviceInfo(
                        id: 3,
                        uid: "atv",
                        name: "Living Room Apple TV",
                        isOutputCapable: true,
                        isAggregate: false
                    ),
                    category: .airplay,
                    supportsVolume: false,
                    volume: 1.0
                ),
            ]
            manager.primaryDeviceID = manager.devices.first?.id
            return AudioDeviceSelectorModel(
                audioManager: manager,
                isPrimary: true
            )
        }
    #endif
}

struct AudioDeviceSelectorView: View {
    @ObservedObject var viewModel: AudioDeviceSelectorModel
    @Namespace private var audioNamespace
    @State private var deviceListContentHeight: CGFloat = 0
    private let deviceListMaxHeight: CGFloat = 220
    private let deviceListFallbackHeight: CGFloat = 160

    private var currentDeviceListHeight: CGFloat {
        let measured =
            deviceListContentHeight > 0
            ? deviceListContentHeight : deviceListFallbackHeight
        return min(measured, deviceListMaxHeight)
    }

    var body: some View {
        VStack {
            if viewModel.isExpanded {
                expandedView
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(
                                with: .scale(scale: 0.98)
                            ),
                            removal: .opacity.combined(
                                with: .scale(scale: 0.92)
                            )
                        )
                    )
            } else {
                controlSurface(cornerRadius: 20) {
                    collapsedView
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(
                                    with: .scale(scale: 0.98)
                                ),
                                removal: .opacity.combined(
                                    with: .scale(scale: 0.92)
                                )
                            )
                        )
                }
            }
        }
        .animation(
            .spring(response: 0.36, dampingFraction: 0.85),
            value: viewModel.isExpanded
        )
    }

    private var collapsedView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(.ultraThinMaterial.opacity(0.4))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(
                            systemName: viewModel.currentDevice?.category
                                .iconName ?? "speaker.slash"
                        )
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            viewModel.isAudioEnabled
                                ? Color.accentColor : Color.secondary
                        )
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.currentDevice?.name ?? "Not Connected")
                        .font(.callout.weight(.semibold))
                    volumeSlider(compact: true)
                }

                Spacer()

                Image(
                    systemName: viewModel.isExpanded
                        ? "chevron.down" : "chevron.right"
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { viewModel.isExpanded.toggle() } }
        }
    }

    private var expandedView: some View {
        controlSurface(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                collapsedView
                Divider().opacity(0.2)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if viewModel.devices.isEmpty {
                            Text("No audio devices available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            section(title: "Audio Devices") {
                                ForEach(viewModel.devices) { device in
                                    AudioDeviceRow(
                                        device: device,
                                        isSelected: viewModel.selectedDeviceID
                                            == device.id,
                                        action: {
                                            viewModel.selectDevice(device)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.bottom, 4)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: DeviceListHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    )
                }
                .frame(height: currentDeviceListHeight)
                .frame(maxWidth: .infinity)
                .onPreferenceChange(DeviceListHeightKey.self) {
                    deviceListContentHeight = $0
                }

                Button(action: viewModel.refreshDevices) {
                    HStack {
                        Spacer()
                        if viewModel.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .labelStyle(.titleAndIcon)
                                .font(.footnote)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func volumeSlider(compact: Bool) -> some View {
        let slider = Slider(
            value: Binding(
                get: { viewModel.currentVolume },
                set: { viewModel.setVolume($0) }
            ),
            in: 0...1
        )
        .disabled(
            !(viewModel.currentDevice?.supportsVolume ?? false)
                || !viewModel.isAudioEnabled
        )
        .tint(.accentColor)

        HStack(spacing: 8) {
            slider
        }
        .opacity(viewModel.currentDevice == nil ? 0.45 : 1)
        .animation(
            .easeInOut(duration: 0.2),
            value: viewModel.currentDevice?.supportsVolume
        )
        .padding(.top, compact ? 0 : 4)
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            content()
        }
    }

    @ViewBuilder
    private func controlSurface<Content: View>(
        cornerRadius: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .matchedGeometryEffect(
                        id: "audioBackground",
                        in: audioNamespace
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.06))
                    .matchedGeometryEffect(
                        id: "audioBorder",
                        in: audioNamespace
                    )
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 6)
    }
}

private struct AudioDeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: device.category.iconName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(
                        isSelected ? Color.accentColor : Color.secondary
                    )
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.callout)
                    Text(device.category.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(Color.accentColor))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.white.opacity(0.14)
                            : Color.white.opacity(0.04)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DeviceListHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#if DEBUG
    #Preview("Audio Device Control") {
        VStack(alignment: .leading, spacing: 16) {
            AudioDeviceSelectorView(viewModel: .preview)
                .padding()
        }
        .frame(width: 320, height: 320)
        .background(Color.black)
    }
#endif
