import Cocoa
import SwiftUI

class OverlayController {
    // Single shortcut popup (near cursor)
    private var popupWindow: NSPanel?
    private var dismissTimer: Timer?
    private let displayDuration: TimeInterval = 1.5

    // Full shortcuts overlay (centered)
    private var fullOverlayWindow: NSPanel?
    private var isFullOverlayVisible = false

    // MARK: - Single Shortcut Popup

    func show(shortcut: Shortcut) {
        dismissTimer?.invalidate()

        // Get cursor position
        let mouseLocation = NSEvent.mouseLocation

        // Create or update window
        if popupWindow == nil {
            createPopupWindow()
        }

        guard let window = popupWindow else { return }

        // Update content
        let hostingView = NSHostingView(rootView: OverlayView(shortcut: shortcut))
        hostingView.frame = NSRect(x: 0, y: 0, width: 200, height: 80)
        window.contentView = hostingView

        // Size to fit content
        let fittingSize = hostingView.fittingSize
        let padding: CGFloat = 20
        let windowWidth = max(fittingSize.width + padding, 80)
        let windowHeight = max(fittingSize.height + padding, 50)

        // Position near cursor with offset
        var x = mouseLocation.x + 20
        var y = mouseLocation.y - windowHeight - 10

        // Keep on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame

            if x + windowWidth > screenFrame.maxX {
                x = mouseLocation.x - windowWidth - 20
            }
            if x < screenFrame.minX {
                x = screenFrame.minX + 10
            }
            if y < screenFrame.minY {
                y = mouseLocation.y + 30
            }
            if y + windowHeight > screenFrame.maxY {
                y = screenFrame.maxY - windowHeight - 10
            }
        }

        window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)

        // Show with fade in
        window.alphaValue = 0
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            window.animator().alphaValue = 1
        }

        // Schedule dismiss
        dismissTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            self?.dismissPopup()
        }
    }

    private func createPopupWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true

        popupWindow = panel
    }

    private func dismissPopup() {
        guard let window = popupWindow else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
        })
    }

    // MARK: - Full Shortcuts Overlay

    func showAllShortcuts(sections: [MenuSection], modifiers: NSEvent.ModifierFlags) {
        // Create window if needed
        if fullOverlayWindow == nil {
            createFullOverlayWindow()
        }

        guard let window = fullOverlayWindow else { return }

        // Update content
        let overlayView = ShortcutsOverlayView(sections: sections, activeModifiers: modifiers)
        let hostingView = NSHostingView(rootView: overlayView)

        // Calculate size
        let fittingSize = hostingView.fittingSize
        let windowWidth = min(fittingSize.width, 920)
        let windowHeight = min(fittingSize.height, 650)

        hostingView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        window.contentView = hostingView

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let x = (screenFrame.width - windowWidth) / 2 + screenFrame.origin.x
            let y = (screenFrame.height - windowHeight) / 2 + screenFrame.origin.y
            window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }

        // Show with fade in (only if not already visible)
        if !isFullOverlayVisible {
            window.alphaValue = 0
            window.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                window.animator().alphaValue = 1
            }

            isFullOverlayVisible = true
        } else {
            // Already visible, just update content
            window.orderFrontRegardless()
        }
    }

    func hideAllShortcuts() {
        guard let window = fullOverlayWindow, isFullOverlayVisible else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.isFullOverlayVisible = false
        })
    }

    private func createFullOverlayWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true

        fullOverlayWindow = panel
    }
}
