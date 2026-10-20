import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: Store
    @State private var direction: Direction = .output

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $direction) {
                Text("Output").tag(Direction.output)
                Text("Input").tag(Direction.input)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text("Drag to reorder. The highest connected device is used.")
                .font(.callout)
                .foregroundStyle(.secondary)

            List {
                ForEach(Array(store.rows(direction).enumerated()), id: \.element.id) { index, row in
                    PriorityRowView(rank: index + 1, row: row, direction: direction) {
                        store.forget(row.pattern, direction)
                    }
                }
                .onMove { store.move(direction, from: $0, to: $1) }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            if let error = store.configError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Divider()

            Toggle("Switch devices automatically", isOn: configBinding(\.enabled))
            Toggle("Also play alerts and sound effects on the output device", isOn: configBinding(\.setSoundEffectsDevice))
            Toggle("Launch at login", isOn: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) }))

            HStack {
                Button("Open Config File") { NSWorkspace.shared.open(Config.url) }
                Spacer()
                Button("Reload") { store.refresh() }
            }
        }
        .padding(16)
        .frame(minWidth: 440, minHeight: 480)
    }

    private func configBinding(_ keyPath: WritableKeyPath<Config, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.config[keyPath: keyPath] },
            set: { value in store.update { $0[keyPath: keyPath] = value } }
        )
    }
}

private struct PriorityRowView: View {
    let rank: Int
    let row: PriorityRow
    let direction: Direction
    let forget: () -> Void

    private var isConnected: Bool { row.device != nil }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)

            Image(systemName: direction == .output ? "speaker.wave.2.fill" : "mic.fill")
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(row.pattern)
                if !isConnected {
                    Text("Not connected").font(.caption).foregroundStyle(.secondary)
                } else if let name = row.device?.name, name != row.pattern {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                }
            }
            .opacity(isConnected ? 1 : 0.5)

            Spacer()

            if row.isActive {
                Text("Active")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2), in: Capsule())
            }

            if !isConnected {
                Button("Forget", action: forget)
                    .buttonStyle(.borderless)
                    .help("Remove this device from the list")
            }
        }
        .padding(.vertical, 3)
        .contextMenu {
            if !isConnected { Button("Forget", action: forget) }
        }
    }
}
