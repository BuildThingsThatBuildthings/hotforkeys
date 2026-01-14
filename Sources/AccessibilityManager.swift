import Cocoa
import ApplicationServices

class AccessibilityManager {
    typealias ShortcutCallback = (Shortcut) -> Void

    private let callback: ShortcutCallback
    private var observer: AXObserver?
    private var currentApp: NSRunningApplication?
    private var appObservation: NSKeyValueObservation?

    init(callback: @escaping ShortcutCallback) {
        self.callback = callback
    }

    func checkPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func startMonitoring() {
        // Watch for frontmost app changes
        appObservation = NSWorkspace.shared.observe(\.frontmostApplication, options: [.new]) { [weak self] _, change in
            if let app = change.newValue {
                self?.switchToApp(app)
            }
        }

        // Start with current app
        if let app = NSWorkspace.shared.frontmostApplication {
            switchToApp(app)
        }
    }

    func stopMonitoring() {
        appObservation?.invalidate()
        appObservation = nil
        removeObserver()
    }

    private func switchToApp(_ app: NSRunningApplication?) {
        guard let app = app, app != currentApp else { return }

        removeObserver()
        currentApp = app
        createObserver(for: app)
    }

    private func createObserver(for app: NSRunningApplication) {
        let pid = app.processIdentifier

        var observer: AXObserver?
        let result = AXObserverCreate(pid, observerCallback, &observer)

        guard result == .success, let observer = observer else {
            return
        }

        self.observer = observer

        let appElement = AXUIElementCreateApplication(pid)

        // Observe menu item selections (primary source of shortcuts)
        AXObserverAddNotification(observer, appElement, kAXMenuItemSelectedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())

        // Observe focused UI element changes (for tracking toolbar/button clicks)
        AXObserverAddNotification(observer, appElement, kAXFocusedUIElementChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())

        // Observe selected children changed (for toolbar items)
        AXObserverAddNotification(observer, appElement, kAXSelectedChildrenChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    private func removeObserver() {
        if let observer = observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
    }

    fileprivate func handleNotification(_ notification: CFString, element: AXUIElement) {
        let notificationName = notification as String

        if notificationName == kAXMenuItemSelectedNotification as String {
            handleMenuItemSelected(element)
        } else if notificationName == kAXFocusedUIElementChangedNotification as String {
            handleFocusedElementChanged(element)
        } else if notificationName == kAXSelectedChildrenChangedNotification as String {
            handleSelectedChildrenChanged(element)
        }
    }

    private func handleMenuItemSelected(_ element: AXUIElement) {
        if let shortcut = extractShortcut(from: element) {
            DispatchQueue.main.async { [weak self] in
                self?.callback(shortcut)
            }
        }
    }

    private func handleFocusedElementChanged(_ element: AXUIElement) {
        // Check if the focused element is a button or toolbar item
        var roleValue: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)

        guard let role = roleValue as? String else { return }

        // Only process buttons and toolbar items
        if role == kAXButtonRole as String || role == "AXToolbarButton" {
            if let shortcut = extractShortcut(from: element) {
                DispatchQueue.main.async { [weak self] in
                    self?.callback(shortcut)
                }
            }
        }
    }

    private func handleSelectedChildrenChanged(_ element: AXUIElement) {
        // Get the selected children
        var selectedValue: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXSelectedChildrenAttribute as CFString, &selectedValue)

        guard let selectedArray = selectedValue as? [AXUIElement], let selected = selectedArray.first else { return }

        if let shortcut = extractShortcut(from: selected) {
            DispatchQueue.main.async { [weak self] in
                self?.callback(shortcut)
            }
        }
    }

    private func extractShortcut(from element: AXUIElement) -> Shortcut? {
        // Get the command key character
        var cmdCharValue: AnyObject?
        let cmdCharResult = AXUIElementCopyAttributeValue(element, kAXMenuItemCmdCharAttribute as CFString, &cmdCharValue)

        // Get modifier keys
        var modifiersValue: AnyObject?
        let modifiersResult = AXUIElementCopyAttributeValue(element, kAXMenuItemCmdModifiersAttribute as CFString, &modifiersValue)

        // Get the title for context
        var titleValue: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
        let title = titleValue as? String

        // If we have a command character, build the shortcut
        if cmdCharResult == .success, let cmdChar = cmdCharValue as? String, !cmdChar.isEmpty {
            var modifiers: NSEvent.ModifierFlags = []

            if modifiersResult == .success, let modifierInt = modifiersValue as? Int {
                // Map AX modifier flags to NSEvent.ModifierFlags
                // AX uses: 0 = Cmd, 1 = Cmd+Shift, 2 = Cmd+Option, 4 = Cmd+Control
                if modifierInt & (1 << 0) != 0 { modifiers.insert(.shift) }
                if modifierInt & (1 << 1) != 0 { modifiers.insert(.option) }
                if modifierInt & (1 << 2) != 0 { modifiers.insert(.control) }
                // Command is always present for menu shortcuts
                modifiers.insert(.command)
            } else {
                // Default: just command
                modifiers = .command
            }

            return Shortcut(key: cmdChar, modifiers: modifiers, actionName: title)
        }

        // Try virtual key for special keys (arrows, function keys, etc.)
        var virtualKeyValue: AnyObject?
        let virtualKeyResult = AXUIElementCopyAttributeValue(element, kAXMenuItemCmdVirtualKeyAttribute as CFString, &virtualKeyValue)

        if virtualKeyResult == .success, let virtualKey = virtualKeyValue as? Int {
            let keyString = virtualKeyToString(virtualKey)

            var modifiers: NSEvent.ModifierFlags = [.command]
            if modifiersResult == .success, let modifierInt = modifiersValue as? Int {
                if modifierInt & (1 << 0) != 0 { modifiers.insert(.shift) }
                if modifierInt & (1 << 1) != 0 { modifiers.insert(.option) }
                if modifierInt & (1 << 2) != 0 { modifiers.insert(.control) }
            }

            return Shortcut(key: keyString, modifiers: modifiers, actionName: title)
        }

        // Fall back to known shortcuts database
        if let title = title {
            return HotkeyDatabase.lookup(actionName: title, appName: currentApp?.localizedName)
        }

        return nil
    }

    private func virtualKeyToString(_ keyCode: Int) -> String {
        switch keyCode {
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Escape"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return "?"
        }
    }
}

// C callback for AXObserver
private func observerCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }
    let manager = Unmanaged<AccessibilityManager>.fromOpaque(refcon).takeUnretainedValue()
    manager.handleNotification(notification, element: element)
}
