import CoreAudio
import Foundation
import ServiceManagement
import os

private let log = Logger(subsystem: "local.audio-device-priorities", category: "app")

/// One entry of a priority list, paired with the connected device it matches, if any.
struct PriorityRow: Identifiable {
    let pattern: String
    let device: AudioDevice?
    let isActive: Bool

    var id: String { pattern }
}

/// Owns the config and the device state, and does the actual switching.
@MainActor
final class Store: ObservableObject {
    @Published private(set) var config = Config()
    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var current: [Direction: AudioDeviceID] = [:]
    @Published private(set) var configError: String?
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    func rows(_ direction: Direction) -> [PriorityRow] {
        let available = devices.filter { $0.supports(direction) }
        return config[direction].map { pattern in
            let device = available.first { Config.matches(pattern, $0) }
            return PriorityRow(pattern: pattern, device: device, isActive: device != nil && device?.id == current[direction])
        }
    }

    func currentDevice(_ direction: Direction) -> AudioDevice? {
        devices.first { $0.id == current[direction] && $0.supports(direction) }
    }

    /// Re-reads config and devices, adds newly seen devices to the bottom of the lists, and applies priorities.
    func refresh() {
        reloadConfig()
        devices = AudioSystem.devices()
        if configError == nil {
            var changed = false
            for direction in Direction.allCases {
                // When a list is first filled, keep whatever device is in use now at the top.
                let currentID = AudioSystem.defaultDevice(direction)
                let ordered = config[direction].isEmpty
                    ? devices.filter { $0.id == currentID } + devices.filter { $0.id != currentID }
                    : devices
                for device in ordered where device.supports(direction) {
                    if !config[direction].contains(where: { Config.matches($0, device) }) {
                        config[direction].append(device.name)
                        changed = true
                    }
                }
            }
            if changed { save() }
        }
        apply()
    }

    func refreshCurrent() {
        var result: [Direction: AudioDeviceID] = [:]
        for direction in Direction.allCases { result[direction] = AudioSystem.defaultDevice(direction) }
        current = result
    }

    func update(_ change: (inout Config) -> Void) {
        reloadConfig()
        guard configError == nil else { return }
        change(&config)
        save()
        apply()
    }

    func move(_ direction: Direction, from source: IndexSet, to destination: Int) {
        update { $0[direction].move(fromOffsets: source, toOffset: destination) }
    }

    func forget(_ pattern: String, _ direction: Direction) {
        update { $0[direction].removeAll { $0 == pattern } }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            log.error("Launch at login: \(error.localizedDescription, privacy: .public)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Private

    private func apply() {
        defer { refreshCurrent() }
        guard config.enabled else { return }

        for direction in Direction.allCases {
            guard let device = config.preferredDevice(direction, among: devices) else { continue }
            if AudioSystem.defaultDevice(direction) != device.id {
                let ok = AudioSystem.setDefaultDevice(device.id, for: direction)
                log.info("\(direction.title, privacy: .public) -> \(device.name, privacy: .public) (\(ok ? "ok" : "failed", privacy: .public))")
            }
            if direction == .output && config.setSoundEffectsDevice {
                AudioSystem.setSoundEffectsDevice(device.id)
            }
        }
    }

    private func reloadConfig() {
        do {
            config = try Config.load()
            configError = nil
        } catch {
            configError = "Config file is invalid: \(error.localizedDescription)"
            log.error("\(self.configError ?? "", privacy: .public)")
        }
    }

    private func save() {
        do {
            try config.save()
        } catch {
            configError = "Could not save config: \(error.localizedDescription)"
        }
    }
}
