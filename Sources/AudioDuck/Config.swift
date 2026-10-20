import Foundation

/// User settings, stored as JSON at ~/.config/audio-duck/config.json.
///
/// Each priority entry is matched against a device's name (case-insensitive, `*` and `?`
/// wildcards allowed) or its exact UID. The first entry with a connected device wins.
struct Config: Codable {
    var enabled = true
    var setSoundEffectsDevice = true
    var output: [String] = []
    var input: [String] = []

    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/audio-duck/config.json")

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        setSoundEffectsDevice = try c.decodeIfPresent(Bool.self, forKey: .setSoundEffectsDevice) ?? true
        output = try c.decodeIfPresent([String].self, forKey: .output) ?? []
        input = try c.decodeIfPresent([String].self, forKey: .input) ?? []
    }

    subscript(direction: Direction) -> [String] {
        get { direction == .output ? output : input }
        set { if direction == .output { output = newValue } else { input = newValue } }
    }

    /// Where the config lived before the app was renamed to Audio Duck.
    private static let legacyURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/audio-device-priorities/config.json")

    static func load() throws -> Config {
        migrateLegacyConfig()
        guard FileManager.default.fileExists(atPath: url.path) else { return Config() }
        return try JSONDecoder().decode(Config.self, from: Data(contentsOf: url))
    }

    private static func migrateLegacyConfig() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path), fm.fileExists(atPath: legacyURL.path) else { return }
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if (try? fm.moveItem(at: legacyURL, to: url)) != nil {
            try? fm.removeItem(at: legacyURL.deletingLastPathComponent())
        }
    }

    func save() throws {
        try FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: Self.url, options: .atomic)
    }

    static func matches(_ pattern: String, _ device: AudioDevice) -> Bool {
        if pattern.caseInsensitiveCompare(device.uid) == .orderedSame { return true }
        return NSPredicate(format: "SELF LIKE[c] %@", pattern).evaluate(with: device.name)
    }

    /// The highest-priority connected device for `direction`, if any entry matches.
    func preferredDevice(_ direction: Direction, among devices: [AudioDevice]) -> AudioDevice? {
        let candidates = devices.filter { $0.supports(direction) }
        for pattern in self[direction] {
            if let device = candidates.first(where: { Self.matches(pattern, $0) }) { return device }
        }
        return nil
    }
}
