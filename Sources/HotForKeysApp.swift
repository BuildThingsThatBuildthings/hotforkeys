import SwiftUI
import Cocoa

@main
struct HotForKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var accessibilityManager: AccessibilityManager!
    private var overlayController: OverlayController!
    private var isEnabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupOverlay()
        setupAccessibility()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "HotForKeys")
        }

        let menu = NSMenu()

        let enableItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enableItem.state = .on
        menu.addItem(enableItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit HotForKeys", action: #selector(quit), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func setupOverlay() {
        overlayController = OverlayController()
    }

    private func setupAccessibility() {
        accessibilityManager = AccessibilityManager { [weak self] shortcut in
            guard let self = self, self.isEnabled else { return }
            self.overlayController.show(shortcut: shortcut)
        }

        if !accessibilityManager.checkPermissions() {
            showPermissionAlert()
        }

        accessibilityManager.startMonitoring()
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "HotForKeys needs Accessibility access to monitor your actions and show keyboard shortcuts.\n\nPlease enable it in System Preferences > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        sender.state = isEnabled ? .on : .off

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: isEnabled ? "keyboard" : "keyboard.badge.ellipsis",
                accessibilityDescription: "HotForKeys"
            )
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
