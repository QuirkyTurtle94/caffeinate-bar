import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var process: Process?
    private var selectedMode = "disable"
    private var items: [NSMenuItem] = []
    private var settingsWindow: NSWindow?
    private var startupCheckbox: NSButton?
    private var updatingStartup = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A second launch should not create another menu bar icon or assertion.
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        for (title, mode) in [("caffeinate -d", "-d"), ("caffeinate -i", "-i"), ("Disable", "disable")] {
            let item = NSMenuItem(title: title, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            menu.addItem(item)
            items.append(item)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        statusItem.menu = menu
        refresh()
        registerAtLogin()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                styleMask: [.titled, .closable], backing: .buffered, defer: false
            )
            window.title = "Settings"
            window.isReleasedWhenClosed = false
            let checkbox = NSButton(checkboxWithTitle: "Boot on startup", target: self, action: #selector(toggleStartup(_:)))
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            checkbox.toolTip = "Open CaffeinateBar automatically when you log in to your Mac."
            let content = window.contentView!
            content.addSubview(checkbox)
            NSLayoutConstraint.activate([
                checkbox.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
                checkbox.centerYAnchor.constraint(equalTo: content.centerYAnchor)
            ])
            startupCheckbox = checkbox
            settingsWindow = window
            window.center()
        }
        refreshStartupCheckbox()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshStartupCheckbox()
    }

    private func refreshStartupCheckbox() {
        startupCheckbox?.state = SMAppService.mainApp.status == .enabled ? .on : .off
        startupCheckbox?.isEnabled = !updatingStartup
    }

    @objc private func toggleStartup(_ sender: NSButton) {
        guard !updatingStartup else { return }
        let enable = sender.state == .on
        updatingStartup = true
        sender.isEnabled = false
        Task { @MainActor in
            defer {
                updatingStartup = false
                refreshStartupCheckbox()
            }
            do {
                let service = SMAppService.mainApp
                if enable {
                    if service.status != .enabled && service.status != .requiresApproval {
                        try service.register()
                    }
                    if service.status == .requiresApproval {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                } else if service.status == .enabled || service.status == .requiresApproval {
                    try await service.unregister()
                }
                // Keep an explicit opt-out from being undone on the next launch.
                UserDefaults.standard.set(true, forKey: "loginRegistrationCompleted")
            } catch {
                showError("Could not change startup setting", detail: error.localizedDescription)
            }
        }
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? String, mode != selectedMode else { return }
        stop()
        if mode != "disable" {
            let child = Process()
            child.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
            // Also release the assertion if this app is forcibly terminated.
            child.arguments = [mode, "-w", String(ProcessInfo.processInfo.processIdentifier)]
            child.terminationHandler = { [weak self] finished in
                let pid = finished.processIdentifier
                Task { @MainActor [weak self] in
                    guard let self, self.process?.processIdentifier == pid else { return }
                    self.process = nil
                    self.selectedMode = "disable"
                    self.refresh()
                }
            }
            do {
                try child.run()
                process = child
                selectedMode = mode
            } catch {
                showError("Could not start caffeinate", detail: error.localizedDescription)
            }
        }
        refresh()
    }

    private func stop() {
        let child = process
        process = nil
        if let child, child.isRunning {
            child.terminate()
            child.waitUntilExit()
        }
        selectedMode = "disable"
    }

    private func refresh() {
        for item in items {
            item.state = (item.representedObject as? String) == selectedMode ? .on : .off
        }
        let active = selectedMode != "disable"
        statusItem.button?.image = NSImage(systemSymbolName: active ? "cup.and.saucer.fill" : "cup.and.saucer", accessibilityDescription: "CaffeinateBar")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = active ? "caffeinate \(selectedMode) is active" : "Caffeinate disabled"
    }

    private func registerAtLogin() {
        // Register once, then respect later changes in macOS Login Items settings.
        guard !UserDefaults.standard.bool(forKey: "loginRegistrationCompleted") else { return }
        do {
            if SMAppService.mainApp.status != .enabled && SMAppService.mainApp.status != .requiresApproval {
                try SMAppService.mainApp.register()
            }
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
            if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                UserDefaults.standard.set(true, forKey: "loginRegistrationCompleted")
            }
        } catch {
            showError("Could not enable launch at login", detail: "You can add CaffeinateBar in System Settings → General → Login Items.\n\n\(error.localizedDescription)")
        }
    }

    private func showError(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.runModal()
    }

    func applicationWillTerminate(_ notification: Notification) { stop() }
}

// Read-only diagnostics for checking the installed bundle's login registration.
if CommandLine.arguments.contains("--login-status") {
    switch SMAppService.mainApp.status {
    case .enabled: print("enabled")
    case .requiresApproval: print("requires approval")
    case .notRegistered: print("not registered")
    case .notFound: print("not found")
    @unknown default: print("unknown")
    }
} else {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
