import Foundation
import Combine
import CoreAudio
import AudioToolbox

public struct AudioDeviceInfo: Identifiable, Hashable {
    public let id: AudioObjectID
    public let uid: String
    public let name: String
    public let isOutputCapable: Bool
    public let isAggregate: Bool
}

public final class AudioAggregateManager: ObservableObject {
    @Published public private(set) var outputDevices: [AudioDeviceInfo] = []
    @Published public private(set) var aggregateEnabled: Bool = false
    @Published public private(set) var statusMessage: String = ""

    // Track IDs for lifecycle
    private var createdAggregateID: AudioObjectID = 0
    private var previousDefaultOutput: AudioObjectID = 0
    public init() {
        refreshDevices()
        previousDefaultOutput = getDefaultOutputDevice()
    }

    deinit {
        // Best effort cleanup if still enabled
        if aggregateEnabled, createdAggregateID != 0 {
            _ = setDefaultOutputDevice(previousDefaultOutput)
            _ = destroyAggregateDevice(createdAggregateID)
        }
    }

    // MARK: - Public API

    public func refreshDevices() {
        outputDevices = fetchAllDevices().filter { $0.isOutputCapable }
    }
    
    public func readLiveAggregateSubDevices() -> (primaryDevice: AudioDeviceInfo, secondaryDevice: AudioDeviceInfo)? {
        let aggregateID = createdAggregateID
        guard aggregateID != 0 else { return nil }

        // 1) Try master UID
        var addrMaster = AudioObjectPropertyAddress(
            mSelector: kAudioAggregateDevicePropertyMainSubDevice, // SDK symbol for master subdevice
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        if AudioObjectGetPropertyDataSize(aggregateID, &addrMaster, 0, nil, &size) != noErr || size == 0 {
            return nil
        }
        var masterUID: String?
        if size > 0 {
            var cfMasterUnm: Unmanaged<CFString>? = nil
            let status = withUnsafeMutablePointer(to: &cfMasterUnm) {
                AudioObjectGetPropertyData(aggregateID, &addrMaster, 0, nil, &size, $0)
            }
            if status == noErr, let unm = cfMasterUnm {
                let cf = unm.takeUnretainedValue()
                masterUID = cf as String
            }
        }
        
        guard masterUID != nil else { return nil }
        
        let masterID = audioObjectID(forUID: masterUID!)

        // 2) Read subdevice list
        var addrList = AudioObjectPropertyAddress(
            mSelector: kAudioAggregateDevicePropertyActiveSubDeviceList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var listSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(aggregateID, &addrList, 0, nil, &listSize) == noErr, listSize > 0 else {
            return nil
        }
        
        let deviceCount = Int(listSize) / MemoryLayout<AudioObjectID>.size
        guard deviceCount > 0 else { return nil }
        var deviceIDs = Array(repeating: AudioObjectID(0), count: deviceCount)
        // Use a safe buffer pointer when passing the array to C
        deviceIDs.withUnsafeMutableBufferPointer { ptr in
            if let base = ptr.baseAddress {
                _ = AudioObjectGetPropertyData(aggregateID, &addrList, 0, nil, &listSize, base)
            }
        }

        guard deviceIDs.count >= 2 else { return nil }

        // determine master and secondary
        let masterIndex: Int
        if let m = masterID, let idx = deviceIDs.firstIndex(of: m) { masterIndex = idx }
        else { masterIndex = 0 }

        let secondaryIndex = (masterIndex == 0) ? 1 : 0
        return (primaryDevice: getDeviceInfo(forID: deviceIDs[masterIndex]), secondaryDevice: getDeviceInfo(forID: deviceIDs[secondaryIndex]))
    }

    public func deviceHasVolumeControl(_ id: AudioObjectID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        return AudioObjectHasProperty(id, &addr)
    }

    public func getDeviceVolume(_ id: AudioObjectID) -> Float? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &volume)
        guard status == noErr else { return nil }
        return Float(volume)
    }

    public func setDeviceVolume(_ id: AudioObjectID, value: Float) -> OSStatus {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var v = Float32(max(0, min(1, value)))
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(id, &addr, 0, nil, size, &v)
    }

    public func enableAggregate(primary: AudioDeviceInfo, secondary: AudioDeviceInfo, name: String = "Multi-Output (App)") {
        guard primary.id != secondary.id else {
            statusMessage = "Choose two different devices."
            return
        }
        // Build and create aggregate
        let masterUID = primary.uid
        let subDevices: [(uid: String, driftCompensate: Bool)] = [
            (uid: primary.uid, driftCompensate: false), // Master: no drift compensation
            (uid: secondary.uid, driftCompensate: true) // Secondary: enable drift compensation
        ]

        switch createAggregateDevice(name: name, masterSubDeviceUID: masterUID, subDevices: subDevices) {
        case .success(let newID):
            createdAggregateID = newID
            previousDefaultOutput = getDefaultOutputDevice()
            let setOut = setDefaultOutputDevice(createdAggregateID)
            let setSys = setDefaultSystemOutputDevice(createdAggregateID)
            if setOut == noErr && setSys == noErr {
                aggregateEnabled = true
                statusMessage = "Enabled multi-output: \(name)"
            } else {
                statusMessage = "Created aggregate but failed to set as default (out: \(setOut), sys: \(setSys))."
            }
        case .failure(let err):
            statusMessage = "Failed to create aggregate (\(err.localizedDescription))."
        }
    }

    public func disableAggregate() {
        guard aggregateEnabled, createdAggregateID != 0 else { return }
        let setOut = setDefaultOutputDevice(previousDefaultOutput)
        let setSys = setDefaultSystemOutputDevice(previousDefaultOutput)
        let destroyErr = destroyAggregateDevice(createdAggregateID)
        if setOut == noErr && setSys == noErr && destroyErr == noErr {
            statusMessage = "Disabled multi-output and restored previous default."
        } else {
            statusMessage = "Disabled with warnings (out: \(setOut), sys: \(setSys), destroy: \(destroyErr))."
        }
        createdAggregateID = 0
        aggregateEnabled = false
    }

    // MARK: - Core Audio Helpers

    private func fetchAllDevices() -> [AudioDeviceInfo] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize)
        guard status == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        guard deviceCount > 0 else { return [] }
        var deviceIDs = Array(repeating: AudioObjectID(0), count: deviceCount)
        // Use a safe buffer pointer when passing the array to C
        deviceIDs.withUnsafeMutableBufferPointer { ptr in
            if let base = ptr.baseAddress {
                _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize, base)
            }
        }

        var results: [AudioDeviceInfo] = []
        results.reserveCapacity(deviceIDs.count)

        for id in deviceIDs {
            results.append(getDeviceInfo(forID: id))
        }
        return results
    }
    
    private func getDeviceInfo(forID id: AudioObjectID) -> AudioDeviceInfo {
        let name = getDeviceName(id) ?? "Unknown Device"
        let uid = getDeviceUID(id) ?? ""
        let isAgg = getIsAggregate(id)
        let isOut = deviceHasOutputChannels(id)
        return AudioDeviceInfo(id: id, uid: uid, name: name, isOutputCapable: isOut, isAggregate: isAgg)
    }

    private func getDeviceName(_ id: AudioObjectID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &dataSize) == noErr else { return nil }

        var unmanaged: Unmanaged<CFString>? = nil
        let status = withUnsafeMutablePointer(to: &unmanaged) { ptr -> OSStatus in
            return AudioObjectGetPropertyData(id, &addr, 0, nil, &dataSize, ptr)
        }
        guard status == noErr, let cf = unmanaged?.takeRetainedValue() else { return nil }
        return cf as String
    }

    private func getDeviceUID(_ id: AudioObjectID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &dataSize) == noErr else { return nil }

        var unmanaged: Unmanaged<CFString>? = nil
        let status = withUnsafeMutablePointer(to: &unmanaged) { ptr -> OSStatus in
            return AudioObjectGetPropertyData(id, &addr, 0, nil, &dataSize, ptr)
        }
        guard status == noErr, let cf = unmanaged?.takeRetainedValue() else { return nil }
        return cf as String
    }

    private func getIsAggregate(_ id: AudioObjectID) -> Bool {
        // Determine if the device is an aggregate by checking its class ID
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyClass,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var classID = AudioClassID(0)
        var size = UInt32(MemoryLayout<AudioClassID>.size)
        let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &classID)
        if status != noErr { return false }
        return classID == kAudioAggregateDeviceClassID
    }

    private func deviceHasOutputChannels(_ id: AudioObjectID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr else { return false }
        guard size > 0 else { return false }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw)
        guard status == noErr else { return false }
        let ablPtr = UnsafeMutableAudioBufferListPointer(raw.bindMemory(to: AudioBufferList.self, capacity: 1))
        var channels = 0
        for buf in ablPtr {
            channels += Int(buf.mNumberChannels)
        }
        return channels > 0
    }

    private func getDefaultOutputDevice() -> AudioObjectID {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dev = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        _ = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev)
        return dev
    }

    @discardableResult
    private func setDefaultOutputDevice(_ id: AudioObjectID) -> OSStatus {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dev = id
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &dev)
    }

    @discardableResult
    private func setDefaultSystemOutputDevice(_ id: AudioObjectID) -> OSStatus {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dev = id
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, size, &dev)
    }

    private enum AggError: Error { case creationFailed(OSStatus) }

    private func createAggregateDevice(name: String, masterSubDeviceUID: String, subDevices: [(uid: String, driftCompensate: Bool)]) -> Result<AudioObjectID, Error> {
        // Build sub-device dictionaries
        let subDicts: [[String: Any]] = subDevices.map { entry in
            [
                kAudioSubDeviceUIDKey as String: entry.uid,
                kAudioSubDeviceDriftCompensationKey as String: entry.driftCompensate
            ]
        }

        // Compose aggregate dictionary using Swift String keys and bridge at call site
        let uid = "com.example.app.aggregate.\(UUID().uuidString)"
        let aggDictSwift: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: name,
            kAudioAggregateDeviceUIDKey as String: uid,
            // Make the aggregate public so it appears in System Settings / Sound
            kAudioAggregateDeviceIsPrivateKey as String: false,
            kAudioAggregateDeviceMasterSubDeviceKey as String: masterSubDeviceUID,
            kAudioAggregateDeviceSubDeviceListKey as String: subDicts,
            kAudioAggregateDeviceIsStackedKey as String: true
        ]

        var newID: AudioObjectID = 0
        let status = AudioHardwareCreateAggregateDevice(aggDictSwift as CFDictionary, &newID)
        if status == noErr, newID != 0 {
            return .success(newID)
        } else {
            return .failure(AggError.creationFailed(status))
        }
    }
    
    private func audioObjectID(forUID uid: String) -> AudioObjectID? {
        var uidCF = uid as CFString
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDeviceForUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            UInt32(MemoryLayout<CFString>.size),
            &uidCF,
            &size,
            &deviceID
        )

        return status == noErr ? deviceID : nil
    }


    @discardableResult
    private func destroyAggregateDevice(_ id: AudioObjectID) -> OSStatus {
        return AudioHardwareDestroyAggregateDevice(id)
    }
}
