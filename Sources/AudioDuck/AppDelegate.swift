import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = Store()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var pendingRefresh: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = DuckShape.menuBarImage()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        let firstLaunch = !FileManager.default.fileExists(atPath: Config.url.path)
        store.refresh()

        AudioSystem.observeDeviceList { [weak self] in self?.scheduleRefresh() }
        AudioSystem.observeDefaultDevices { [weak self] in self?.store.refreshCurrent() }

        if firstLaunch { showSettings() }
    }

    /// Opening the app again (e.g. from Finder or Spotlight) shows the settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    /// Devices often appear in stages (e.g. Bluetooth headsets), so wait for things to settle.
    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.store.refresh() }
        pendingRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: work)
    }

    private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(store: store)))
            window.title = "Audio Duck"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 460, height: 540))
            window.center()
            settingsWindow = window
        }
        store.refresh()
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        store.refreshCurrent()

        for direction in Direction.allCases {
            let item = NSMenuItem(title: "\(direction.title): \(store.currentDevice(direction)?.name ?? "None")", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Switch automatically", state: store.config.enabled) { [weak self] in
            self?.store.update { $0.enabled.toggle() }
        })
        menu.addItem(ClosureMenuItem("Settings…", key: ",") { [weak self] in self?.showSettings() })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Quit", key: "q") { NSApp.terminate(nil) })
    }
}

/// NSMenuItem that runs a closure instead of using target/action plumbing.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", state: Bool = false, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        self.target = self
        self.state = state ? .on : .off
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func run() { handler() }
}
