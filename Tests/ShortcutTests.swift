import Cocoa
import XCTest
@testable import HotForKeys

final class ShortcutTests: XCTestCase {
    func testAXModifiersIncludeCommandOnlyWhenImplied() {
        XCTAssertEqual(Shortcut.modifiers(fromAXMask: nil), .command)
        XCTAssertEqual(Shortcut.modifiers(fromAXMask: 0), .command)
        XCTAssertEqual(Shortcut.modifiers(fromAXMask: 7), [.command, .shift, .option, .control])
        XCTAssertEqual(Shortcut.modifiers(fromAXMask: 8), [])
        XCTAssertEqual(Shortcut.modifiers(fromAXMask: 9), .shift)
        XCTAssertEqual(Shortcut.modifiers(fromAXMask: 10), .option)
        XCTAssertEqual(Shortcut.modifiers(fromAXMask: 12), .control)
        XCTAssertEqual(Shortcut.modifiers(fromAXMask: 15), [.shift, .option, .control])
    }

    func testDisplayUsesConventionalModifierOrder() {
        let shortcut = Shortcut(key: "s", modifiers: [.command, .shift, .control, .option], actionName: nil)
        XCTAssertEqual(shortcut.displayString, "⌃⌥⇧⌘S")
    }

    func testSystemFallbackInitializesAndReturnsCopy() {
        let shortcut = HotkeyDatabase.lookup(actionName: "Copy", appName: nil)
        XCTAssertEqual(shortcut?.key, "C")
        XCTAssertEqual(shortcut?.modifiers, .command)
    }

    func testAppSpecificFallbackAndEllipsis() {
        let shortcut = HotkeyDatabase.lookup(actionName: "Open…", appName: "Finder")
        XCTAssertEqual(shortcut?.key, "O")
        XCTAssertEqual(shortcut?.modifiers, .command)
    }

    func testPreviouslyDuplicatedFallbacksAreAvailable() {
        XCTAssertEqual(HotkeyDatabase.lookup(actionName: "Next Tab", appName: nil)?.displayString, "⇧⌘]")
        XCTAssertEqual(HotkeyDatabase.lookup(actionName: "Previous Tab", appName: nil)?.displayString, "⇧⌘[")
        XCTAssertEqual(HotkeyDatabase.lookup(actionName: "Quick Look", appName: nil)?.displayString, "⌘Y")
    }
}
