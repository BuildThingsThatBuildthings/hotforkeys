import Cocoa
import ApplicationServices

class AccessibilityManager {
    typealias ShortcutCallback = (Shortcut) -> Void
    typealias ModifierCallback = (NSEvent.ModifierFlags, Bool) -> Void  // (modifiers, isPressed)

    private let shortcutCallback: ShortcutCallback
    private var modifierCallback: ModifierCallback?
    private var observer: AXObserver?
    private var currentApp: NSRunningApplication?
    private var appObservation: NSKeyValueObservation?

    // Modifier key monitoring
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var currentModifiers: NSEvent.ModifierFlags = []
    private var modifierTimer: Timer?
    private let modifierDelay: TimeInterval = 0.3  // Delay before showing overlay

    init(shortcutCallback: @escaping ShortcutCallback, modifierCallback: ModifierCallback? = nil) {
        self.shortcutCallback = shortcutCallback
        self.modifierCallback = modifierCallback
    }

    func checkPermissions() -> Bool {
        let trusted = AXIsProcessTrusted()
        NSLog("[HotForKeys] Accessibility trusted: \(trusted)")
        return trusted
    }

    func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let result = AXIsProcessTrustedWithOptions(options)
        NSLog("[HotForKeys] Permission request result: \(result)")
    }

    func startMonitoring() {
        guard appObservation == nil else { return }
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

        // Start modifier key monitoring
        startModifierMonitoring()
    }

    func stopMonitoring() {
        appObservation?.invalidate()
        appObservation = nil
        removeObserver()
        stopModifierMonitoring()
        currentApp = nil
    }

    // MARK: - Modifier Key Monitoring

    private func startModifierMonitoring() {
        NSLog("[HotForKeys] Starting modifier monitoring...")

        // Global monitor for when app is not focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            NSLog("[HotForKeys] Global modifier event: \(event.modifierFlags.rawValue)")
            self?.handleModifierChange(event)
        }

        // Local monitor for when app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            NSLog("[HotForKeys] Local modifier event: \(event.modifierFlags.rawValue)")
            self?.handleModifierChange(event)
            return event
        }

        NSLog("[HotForKeys] Global monitor: \(globalMonitor != nil ? "created" : "FAILED")")
        NSLog("[HotForKeys] Local monitor: \(localMonitor != nil ? "created" : "FAILED")")
    }

    private func stopModifierMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        resetModifierState()
    }

    private func resetModifierState() {
        modifierTimer?.invalidate()
        modifierTimer = nil
        let hadModifiers = !currentModifiers.isEmpty
        currentModifiers = []
        if hadModifiers { modifierCallback?([], false) }
    }

    private func handleModifierChange(_ event: NSEvent) {
        handleModifierChange(event.modifierFlags)
    }

    // Accept flags directly so lifecycle tests do not install event monitors.
    func handleModifierChange(_ flags: NSEvent.ModifierFlags) {
        let newModifiers = flags.intersection([.command, .option, .control, .shift])
        let previousModifiers = currentModifiers
        // Left/right modifier and Caps Lock events can leave the chord unchanged.
        guard newModifiers != previousModifiers else { return }
        currentModifiers = newModifiers
        modifierTimer?.invalidate()
        modifierTimer = nil

        guard !newModifiers.isEmpty else {
            modifierCallback?([], false)
            return
        }

        let delay = previousModifiers.isEmpty ? modifierDelay : 0.1
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, self.currentModifiers == newModifiers else { return }
            self.modifierTimer = nil
            // The timer runs on main. Avoid queuing a stale show after release.
            self.modifierCallback?(newModifiers, true)
        }
        modifierTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func getCurrentApp() -> NSRunningApplication? {
        return NSWorkspace.shared.frontmostApplication ?? currentApp
    }

    private func switchToApp(_ app: NSRunningApplication?) {
        guard app != currentApp else { return }
        resetModifierState()
        removeObserver()
        currentApp = app
        if let app = app { createObserver(for: app) }
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
                self?.shortcutCallback(shortcut)
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
                    self?.shortcutCallback(shortcut)
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
                self?.shortcutCallback(shortcut)
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
            let modifiers = Shortcut.modifiers(fromAXMask: modifiersResult == .success ? modifiersValue as? Int : nil)

            return Shortcut(key: cmdChar, modifiers: modifiers, actionName: title)
        }

        // Try virtual key for special keys (arrows, function keys, etc.)
        var virtualKeyValue: AnyObject?
        let virtualKeyResult = AXUIElementCopyAttributeValue(element, kAXMenuItemCmdVirtualKeyAttribute as CFString, &virtualKeyValue)

        if virtualKeyResult == .success, let virtualKey = virtualKeyValue as? Int {
            let keyString = virtualKeyToString(virtualKey)

            let modifiers = Shortcut.modifiers(fromAXMask: modifiersResult == .success ? modifiersValue as? Int : nil)

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
