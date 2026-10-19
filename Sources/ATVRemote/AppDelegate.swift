import AppKit
import SwiftUI

/// Port of app/main.js — menu bar icon, the single remote window, the tray
/// menu, global hotkeys, power-resume handling, and app lifecycle.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private let vm = RemoteViewModel.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // LSUIElement-equivalent: no Dock icon

        createWindow()
        createStatusItem()
        registerHotkeys()

        NotificationCenter.default.addObserver(forName: .atvSetAlwaysOnTop, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                guard let v = note.object as? Bool else { return }
                self?.window.level = v ? .floating : .normal
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.vm.onPowerResume() }
        }

        NSApplication.shared.appearance = nil // follow system unless overridden in-app

        showWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // ---------------------------------------------------------------- window
    private func createWindow() {
        let root = RootView(vm: vm)
        let hosting = NSHostingView(rootView: root)
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 680),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.contentView = hosting
        w.title = "Apple TV Remote"
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isReleasedWhenClosed = false
        w.isMovableByWindowBackground = true
        w.delegate = self
        window = w
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        vm.setWindowVisible(false)
        return false
    }

    private func positionWindow() {
        guard let button = statusItem.button, let buttonWindow = button.window else {
            window.center()
            return
        }
        let buttonFrame = buttonWindow.convertToScreen(button.frame)
        let screen = NSScreen.screens.first { $0.frame.contains(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY)) } ?? NSScreen.main
        guard let workArea = screen?.visibleFrame else { window.center(); return }

        var x = buttonFrame.midX - window.frame.width / 2
        x = max(workArea.minX + 8, min(x, workArea.maxX - window.frame.width - 8))
        let y = buttonFrame.minY - window.frame.height - 4
        window.setFrameOrigin(NSPoint(x: x, y: max(workArea.minY + 8, y)))
    }

    private func showWindow() {
        positionWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        vm.setWindowVisible(true)
    }

    private func toggleWindow() {
        if window.isVisible {
            window.orderOut(nil)
            vm.setWindowVisible(false)
        } else {
            showWindow()
        }
    }

    // ---------------------------------------------------------------- status item / tray
    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let path = Bundle.module.url(forResource: "IconTemplate", withExtension: "png"),
               let image = NSImage(contentsOf: path) {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            } else {
                button.title = "\u{1F4FA}"
            }
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { toggleWindow(); return }
        if event.type == .rightMouseUp {
            statusItem.menu = buildTrayMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggleWindow()
        }
    }

    private func buildTrayMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Remote", action: #selector(menuOpenRemote), keyEquivalent: "").target = self
        menu.addItem(.separator())

        let alwaysOnTop = NSMenuItem(title: "Always on top", action: #selector(menuToggleAlwaysOnTop(_:)), keyEquivalent: "")
        alwaysOnTop.target = self
        alwaysOnTop.state = vm.alwaysOnTop ? .on : .off
        menu.addItem(alwaysOnTop)

        let appearance = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for (title, mode) in [("Follow system", UIMode.systemmode), ("Dark", UIMode.darkmode), ("Light", UIMode.lightmode)] {
            let item = NSMenuItem(title: title, action: #selector(menuSetTheme(_:)), keyEquivalent: "")
            item.target = self
            item.state = vm.uimode == mode ? .on : .off
            item.representedObject = mode.rawValue
            submenu.addItem(item)
        }
        appearance.submenu = submenu
        menu.addItem(appearance)

        menu.addItem(.separator())
        menu.addItem(withTitle: "About Apple TV Remote", action: #selector(menuAbout), keyEquivalent: "").target = self
        let quit = NSMenuItem(title: "Quit", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    @objc private func menuOpenRemote() { showWindow() }

    @objc private func menuToggleAlwaysOnTop(_ sender: NSMenuItem) {
        let newVal = sender.state != .on
        vm.setAlwaysOnTop(newVal)
    }

    @objc private func menuSetTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = UIMode(rawValue: raw) else { return }
        vm.setTheme(mode)
    }

    @objc private func menuAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Apple TV Remote",
            .credits: NSAttributedString(string: "Brian Harper"),
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "Copyright 2026"
        ])
    }

    @objc private func menuQuit() {
        ServerRunner.shared.stopServer()
        NSApp.terminate(nil)
    }

    // ---------------------------------------------------------------- hotkeys
    private func registerHotkeys() {
        HotkeyManager.shared.onTrigger = { [weak self] in
            Task { @MainActor in self?.toggleWindow() }
        }
        HotkeyManager.shared.registerAll()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregisterAll()
        ServerRunner.shared.stopServer()
    }
}
