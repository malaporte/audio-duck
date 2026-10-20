import CoreAudio
import Foundation

enum Direction: CaseIterable {
    case output, input

    var title: String { self == .output ? "Output" : "Input" }

    var scope: AudioObjectPropertyScope {
        self == .output ? kAudioObjectPropertyScopeOutput : kAudioObjectPropertyScopeInput
    }

    var defaultDeviceSelector: AudioObjectPropertySelector {
        self == .output ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice
    }
}

struct AudioDevice: Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let outputChannels: Int
    let inputChannels: Int

    func supports(_ direction: Direction) -> Bool {
        (direction == .output ? outputChannels : inputChannels) > 0
    }
}

/// Thin wrapper over the CoreAudio HAL C API.
enum AudioSystem {
    private static let system = AudioObjectID(kAudioObjectSystemObject)

    private static func address(
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func devices() -> [AudioDevice] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }

        return ids.compactMap { id in
            guard isAlive(id),
                  let uid = stringProperty(id, kAudioDevicePropertyDeviceUID),
                  let name = stringProperty(id, kAudioObjectPropertyName)
            else { return nil }
            return AudioDevice(
                id: id, uid: uid, name: name,
                outputChannels: channelCount(id, .output),
                inputChannels: channelCount(id, .input)
            )
        }
    }

    static func defaultDevice(_ direction: Direction) -> AudioDeviceID? {
        var addr = address(direction.defaultDeviceSelector)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &id) == noErr, id != 0 else { return nil }
        return id
    }

    @discardableResult
    static func setDefaultDevice(_ id: AudioDeviceID, for direction: Direction) -> Bool {
        setDevice(id, selector: direction.defaultDeviceSelector)
    }

    /// The device used for alerts and sound effects.
    @discardableResult
    static func setSoundEffectsDevice(_ id: AudioDeviceID) -> Bool {
        setDevice(id, selector: kAudioHardwarePropertyDefaultSystemOutputDevice)
    }

    /// Calls `handler` on the main queue whenever devices are added or removed.
    static func observeDeviceList(_ handler: @escaping @MainActor () -> Void) {
        observe(kAudioHardwarePropertyDevices, handler)
    }

    /// Calls `handler` on the main queue whenever the default input or output device changes.
    static func observeDefaultDevices(_ handler: @escaping @MainActor () -> Void) {
        for direction in Direction.allCases { observe(direction.defaultDeviceSelector, handler) }
    }

    private static func observe(_ selector: AudioObjectPropertySelector, _ handler: @escaping @MainActor () -> Void) {
        var addr = address(selector)
        AudioObjectAddPropertyListenerBlock(system, &addr, DispatchQueue.main) { _, _ in
            MainActor.assumeIsolated { handler() }
        }
    }

    // MARK: - Helpers

    private static func setDevice(_ id: AudioDeviceID, selector: AudioObjectPropertySelector) -> Bool {
        var addr = address(selector)
        var id = id
        let status = AudioObjectSetPropertyData(system, &addr, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
        return status == noErr
    }

    private static func isAlive(_ id: AudioDeviceID) -> Bool {
        var addr = address(kAudioDevicePropertyDeviceIsAlive)
        var alive: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &alive) == noErr && alive != 0
    }

    private static func stringProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func channelCount(_ id: AudioDeviceID, _ direction: Direction) -> Int {
        var addr = address(kAudioDevicePropertyStreamConfiguration, direction.scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }

        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, list) == noErr else { return 0 }

        return UnsafeMutableAudioBufferListPointer(list).reduce(0) { $0 + Int($1.mNumberChannels) }
    }
}
