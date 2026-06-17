import SwiftUI
import AppKit

@main
struct SmartNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        // No Settings scene — we manage our own window so it works in .accessory mode.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var notchController: NotchOverlayController!
    private var statusItem: NSStatusItem!
    private var hotKey: HotKeyManager!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        notchController = NotchOverlayController(appState: appState)
        notchController.installWindow()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "sparkles",
                                accessibilityDescription: "SmartNotch")
            btn.image?.isTemplate = true
        }
        statusItem.menu = buildMenu()

        hotKey = HotKeyManager()
        hotKey.onToggle = { [weak self] in
            self?.notchController.toggleVoiceCapture()
        }
        hotKey.onRefresh = { [weak self] in
            self?.notchController.refreshVoiceCapture()
        }
        hotKey.onRapid = { [weak self] in
            self?.notchController.toggleRapidCapture()
        }
        hotKey.start()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let ask = NSMenuItem(title: "Ask SmartNotch…",
                             action: #selector(toggleTextMode), keyEquivalent: "k")
        ask.target = self
        menu.addItem(ask)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…",
                                  action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SmartNotch",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        return menu
    }

    @objc private func toggleTextMode() {
        notchController.openTextMode()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView().environmentObject(appState)
            let hosting = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hosting)
            win.title = "SmartNotch Settings"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.isReleasedWhenClosed = false
            win.center()
            settingsWindow = win
        }
        // Show as a regular window so Dock-less apps can still focus it.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationDidResignActive(_ notification: Notification) {
        // Slip back to accessory mode once Settings loses focus so the
        // Dock icon doesn't linger.
        if settingsWindow?.isVisible != true {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
