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
    private var cachedAppBundleId: String?

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

        if sections.isEmpty {
            AppDelegate.debugLog("WARNING: No menu sections found! This could indicate an accessibility permission issue.")
            showAccessibilityTroubleshoot()
        }
    }

    private func showAccessibilityTroubleshoot() {
        let alert = NSAlert()
        alert.messageText = "Cannot Read Menu Shortcuts"
        alert.informativeText = "HotForKeys cannot access menu bar data. This usually happens after rebuilding the app.\n\nPlease:\n1. Open System Settings → Privacy & Security → Accessibility\n2. Remove HotForKeys from the list\n3. Re-add it by clicking '+' and selecting this app\n4. Restart HotForKeys"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Dismiss")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private static func debugLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [AppDelegate] \(message)\n"
        let logPath = "/tmp/hotforkeys_debug.log"

        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(logMessage.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: logMessage.data(using: .utf8))
        }

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
            let bundleId = app.bundleIdentifier ?? ""
            if bundleId == cachedAppBundleId && !cachedSections.isEmpty {
                overlayController.showAllShortcuts(sections: cachedSections, modifiers: modifiers)
                return
            }

            // Parse menu bar
            let sections = MenuBarParser.parseMenuBar(for: app)
            cachedSections = sections
            cachedAppBundleId = bundleId

            overlayController.showAllShortcuts(sections: sections, modifiers: modifiers)
        } else {
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
            overlayController.hideAllShortcuts()
        }
    }

    @objc private func quit() {
        accessibilityManager.stopMonitoring()
        NSApplication.shared.terminate(nil)
    }
}
