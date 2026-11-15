import Cocoa
import ApplicationServices

struct MenuSection {
    let title: String
    let shortcuts: [Shortcut]
}

class MenuBarParser {

    private static func debugLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        let logPath = "/tmp/hotforkeys_debug.log"

        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(logMessage.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: logMessage.data(using: .utf8))
        }

        NSLog("[MenuBarParser] \(message)")
    }

    static func parseMenuBar(for app: NSRunningApplication) -> [MenuSection] {
        let pid = app.processIdentifier
        debugLog("Parsing menu bar for app: \(app.localizedName ?? "unknown") (pid: \(pid))")

        let appElement = AXUIElementCreateApplication(pid)

        var menuBarValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarValue)

        debugLog("AXUIElementCopyAttributeValue result: \(result.rawValue) (0=success, -25211=apiDisabled, -25204=cannotComplete)")

        guard result == .success, let menuBar = menuBarValue else {
            debugLog("Failed to get menu bar. Result: \(result.rawValue)")
            return []
        }

        let sections = parseMenuBarElement(menuBar as! AXUIElement)
        debugLog("Parsed \(sections.count) sections with total \(sections.reduce(0) { $0 + $1.shortcuts.count }) shortcuts")
        return sections
    }

    private static func parseMenuBarElement(_ menuBar: AXUIElement) -> [MenuSection] {
        var sections: [MenuSection] = []

        // Get menu bar items (File, Edit, View, etc.)
        var childrenValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &childrenValue)

        debugLog("Get children result: \(result.rawValue)")

        guard result == .success, let menuBarItems = childrenValue as? [AXUIElement] else {
            debugLog("Failed to get menu bar children")
            return []
        }

        debugLog("Found \(menuBarItems.count) menu bar items")

        for menuBarItem in menuBarItems {
            // Get the menu title
            var titleValue: AnyObject?
            AXUIElementCopyAttributeValue(menuBarItem, kAXTitleAttribute as CFString, &titleValue)
            let menuTitle = titleValue as? String ?? ""

            // Skip the Apple menu and empty titles
            if menuTitle.isEmpty || menuTitle == "Apple" {
                continue
            }

            // Get the submenu
            var submenuValue: AnyObject?
            let submenuResult = AXUIElementCopyAttributeValue(menuBarItem, kAXChildrenAttribute as CFString, &submenuValue)

            guard submenuResult == .success, let submenus = submenuValue as? [AXUIElement], let submenu = submenus.first else {
                continue
            }

            // Parse menu items
            let shortcuts = parseMenu(submenu)

            if !shortcuts.isEmpty {
                sections.append(MenuSection(title: menuTitle, shortcuts: shortcuts))
            }
        }

        return sections
    }

    private static func parseMenu(_ menu: AXUIElement) -> [Shortcut] {
        var shortcuts: [Shortcut] = []

        var childrenValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &childrenValue)

        guard result == .success, let menuItems = childrenValue as? [AXUIElement] else {
            return []
        }

        for item in menuItems {
            // Check if this is a separator
            var roleValue: AnyObject?
            AXUIElementCopyAttributeValue(item, kAXRoleAttribute as CFString, &roleValue)
            let role = roleValue as? String ?? ""

            if role == "AXMenuItemSeparator" {
                continue
            }

            // Get the title
            var titleValue: AnyObject?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleValue)
            let title = titleValue as? String ?? ""

            if title.isEmpty {
                continue
            }

            // Check for submenu (recursive)
            var submenuValue: AnyObject?
            let submenuResult = AXUIElementCopyAttributeValue(item, kAXChildrenAttribute as CFString, &submenuValue)

            if submenuResult == .success, let submenus = submenuValue as? [AXUIElement], !submenus.isEmpty {
                // Has submenu - recurse
                let subShortcuts = parseMenu(submenus[0])
                shortcuts.append(contentsOf: subShortcuts)
                continue
            }

            // Try to get the keyboard shortcut
            if let shortcut = extractShortcut(from: item, title: title) {
                shortcuts.append(shortcut)
            }
        }

        return shortcuts
    }

    private static func extractShortcut(from element: AXUIElement, title: String) -> Shortcut? {
        // Get the command key character
        var cmdCharValue: AnyObject?
        let cmdCharResult = AXUIElementCopyAttributeValue(element, kAXMenuItemCmdCharAttribute as CFString, &cmdCharValue)

        // Get modifier keys
        var modifiersValue: AnyObject?
        let modifiersResult = AXUIElementCopyAttributeValue(element, kAXMenuItemCmdModifiersAttribute as CFString, &modifiersValue)

        // If we have a command character, build the shortcut
        if cmdCharResult == .success, let cmdChar = cmdCharValue as? String, !cmdChar.isEmpty {
            var modifiers: NSEvent.ModifierFlags = [.command]  // Command is always implied

            if modifiersResult == .success, let modifierInt = modifiersValue as? Int {
                // AX modifier flags: bit 0 = Shift, bit 1 = Option, bit 2 = Control
                if modifierInt & (1 << 0) != 0 { modifiers.insert(.shift) }
                if modifierInt & (1 << 1) != 0 { modifiers.insert(.option) }
                if modifierInt & (1 << 2) != 0 { modifiers.insert(.control) }
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

        return nil
    }

    private static func virtualKeyToString(_ keyCode: Int) -> String {
        switch keyCode {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 117: return "⌦"
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
        case 115: return "↖"
        case 119: return "↘"
        case 116: return "⇞"
        case 121: return "⇟"
        default: return "?"
        }
    }
}
