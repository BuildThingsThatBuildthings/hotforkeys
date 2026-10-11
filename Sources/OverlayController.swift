import Cocoa
import SwiftUI

class OverlayController {
    // Single shortcut popup (near cursor)
    private var popupWindow: NSPanel?
    private var dismissTimer: Timer?
    private let displayDuration: TimeInterval = 1.5
    private var popupGeneration = 0

    // Full shortcuts overlay (centered)
    private var fullOverlayWindow: NSPanel?
    private var isFullOverlayVisible = false
    private var fullOverlayGeneration = 0

    // MARK: - Single Shortcut Popup

    func show(shortcut: Shortcut) {
        dismissTimer?.invalidate()
        popupGeneration += 1

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
        dismissTimer?.invalidate()
        dismissTimer = nil
        guard let window = popupWindow else { return }
        popupGeneration += 1
        let generation = popupGeneration

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard self?.popupGeneration == generation else { return }
            window.orderOut(nil)
        })
    }

    func hide() {
        dismissPopup()
        hideAllShortcuts()
    }

    // MARK: - Full Shortcuts Overlay

    func showAllShortcuts(sections: [MenuSection], modifiers: NSEvent.ModifierFlags) {
        // Create window if needed
        if fullOverlayWindow == nil {
            createFullOverlayWindow()
        }

        guard let window = fullOverlayWindow else { return }
        fullOverlayGeneration += 1

        // A ScrollView needs a bounded viewport, not its unconstrained fitting size.
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 940, height: 640)
        let windowWidth = max(1, min(screenFrame.width - 40, 900))
        let windowHeight = max(1, min(screenFrame.height - 40, 600))
        let overlayView = ShortcutsOverlayView(sections: sections, activeModifiers: modifiers)
            .frame(width: windowWidth, height: windowHeight)
        let hostingView = NSHostingView(rootView: overlayView)

        hostingView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        window.contentView = hostingView

        // Center on screen
        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.midY - windowHeight / 2
        window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)

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
        isFullOverlayVisible = false
        fullOverlayGeneration += 1
        let generation = fullOverlayGeneration

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard self?.fullOverlayGeneration == generation else { return }
            window.orderOut(nil)
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

        // Allow scrolling through the complete menu without activating the app.
        panel.ignoresMouseEvents = false
        fullOverlayWindow = panel
    }
}
