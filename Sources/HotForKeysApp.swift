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

    // Cache for menu bar shortcuts
    private var cachedSections: [MenuSection] = []
    private var cachedAppPID: pid_t?

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
        accessibilityManager = AccessibilityManager(
            shortcutCallback: { [weak self] shortcut in
                guard let self = self, self.isEnabled else { return }
                self.overlayController.show(shortcut: shortcut)
            },
            modifierCallback: { [weak self] modifiers, isPressed in
                guard let self = self, self.isEnabled else { return }
                self.handleModifierChange(modifiers: modifiers, isPressed: isPressed)
            }
        )

        if !accessibilityManager.checkPermissions() {
            NSLog("[HotForKeys] Accessibility not granted, requesting...")
            accessibilityManager.requestPermissions()
            showPermissionAlert()
        } else {
            NSLog("[HotForKeys] Accessibility already granted")
        }

        accessibilityManager.startMonitoring()
        NSLog("[HotForKeys] Monitoring started")

        // Test accessibility on startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.testAccessibility()
        }
    }

    private func testAccessibility() {
        AppDelegate.debugLog("Testing accessibility on startup...")

        guard let app = NSWorkspace.shared.frontmostApplication else {
            AppDelegate.debugLog("No frontmost application found!")
            return
        }

        AppDelegate.debugLog("Frontmost app: \(app.localizedName ?? "unknown") (bundle: \(app.bundleIdentifier ?? "unknown"))")

        let sections = MenuBarParser.parseMenuBar(for: app)
        AppDelegate.debugLog("Startup test result: \(sections.count) sections found")

        // An empty menu is valid (or the app may not expose AX menus). It does
        // not establish a permission failure and must not prompt a permission reset.
        if sections.isEmpty {
            AppDelegate.debugLog("No menu shortcuts exposed by the current application.")
        }
    }

    private static func debugLog(_ message: String) {
        NSLog("[HotForKeys] \(message)")
    }

    private func handleModifierChange(modifiers: NSEvent.ModifierFlags, isPressed: Bool) {
        AppDelegate.debugLog("handleModifierChange: isPressed=\(isPressed), modifiers=\(modifiers.rawValue)")

        if isPressed {
            // Get current app's shortcuts
            guard let app = accessibilityManager.getCurrentApp() else {
                AppDelegate.debugLog("No current app found")
                overlayController.hideAllShortcuts()
                return
            }
            AppDelegate.debugLog("Current app: \(app.localizedName ?? "unknown")")

            // Use cache if same app
            let pid = app.processIdentifier
            if pid == cachedAppPID && !cachedSections.isEmpty {
                overlayController.showAllShortcuts(sections: cachedSections, modifiers: modifiers)
                return
            }

            // Parse menu bar
            let sections = MenuBarParser.parseMenuBar(for: app)
            cachedSections = sections
            cachedAppPID = pid

            overlayController.showAllShortcuts(sections: sections, modifiers: modifiers)
        } else {
            // Menus change with documents and selections. Reparse on the next hold.
            cachedSections = []
            cachedAppPID = nil
            overlayController.hideAllShortcuts()
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "HotForKeys needs Accessibility access to monitor keyboard shortcuts and read application menus.\n\nPlease enable it in System Settings > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
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

        // Hide overlay when disabled
        if !isEnabled {
            accessibilityManager.stopMonitoring()
            cachedSections = []
            cachedAppPID = nil
            overlayController.hide()
        } else {
            accessibilityManager.startMonitoring()
        }
    }

    @objc private func quit() {
        accessibilityManager.stopMonitoring()
        NSApplication.shared.terminate(nil)
    }
}
