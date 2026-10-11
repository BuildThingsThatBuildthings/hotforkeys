import Cocoa
import XCTest
@testable import HotForKeys

final class ModifierMonitoringTests: XCTestCase {
    private func pumpRunLoop(_ duration: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(duration))
    }

    func testDuplicateFlagsDoNotCancelPendingOverlay() {
        var shown: [NSEvent.ModifierFlags] = []
        let manager = AccessibilityManager(shortcutCallback: { _ in }, modifierCallback: { flags, pressed in
            if pressed { shown.append(flags) }
        })
        defer { manager.stopMonitoring() }
        manager.handleModifierChange(.command)
        manager.handleModifierChange([.command, .capsLock])
        pumpRunLoop(0.45)
        XCTAssertEqual(shown, [.command])
    }

    func testReleaseBeforeDelayNeverShowsOverlay() {
        var pressedValues: [Bool] = []
        let manager = AccessibilityManager(shortcutCallback: { _ in }, modifierCallback: { _, pressed in
            pressedValues.append(pressed)
        })
        defer { manager.stopMonitoring() }
        manager.handleModifierChange(.command)
        manager.handleModifierChange([])
        pumpRunLoop(0.45)
        XCTAssertEqual(pressedValues, [false])
    }

    func testChangedChordShowsLatestFlags() {
        var shown: [NSEvent.ModifierFlags] = []
        let manager = AccessibilityManager(shortcutCallback: { _ in }, modifierCallback: { flags, pressed in
            if pressed { shown.append(flags) }
        })
        defer { manager.stopMonitoring() }
        manager.handleModifierChange(.command)
        manager.handleModifierChange([.command, .shift])
        pumpRunLoop(0.45)
        XCTAssertEqual(shown, [[.command, .shift]])
    }

    func testStopHidesOverlayAndResetsHeldModifiers() {
        var pressedValues: [Bool] = []
        let manager = AccessibilityManager(shortcutCallback: { _ in }, modifierCallback: { _, pressed in
            pressedValues.append(pressed)
        })
        defer { manager.stopMonitoring() }
        manager.handleModifierChange(.command)
        pumpRunLoop(0.45)
        manager.stopMonitoring()
        manager.handleModifierChange(.command)
        pumpRunLoop(0.45)
        XCTAssertEqual(pressedValues, [true, false, true])
    }

    func testStopCancelsPendingOverlay() {
        var shown = false
        let manager = AccessibilityManager(shortcutCallback: { _ in }, modifierCallback: { _, pressed in
            shown = shown || pressed
        })
        manager.handleModifierChange(.command)
        manager.stopMonitoring()
        pumpRunLoop(0.45)
        XCTAssertFalse(shown)
    }
}
