import Cocoa
import SwiftUI

class OverlayController {
    private var window: NSPanel?
    private var dismissTimer: Timer?
    private let displayDuration: TimeInterval = 1.5

    func show(shortcut: Shortcut) {
        dismissTimer?.invalidate()

        // Get cursor position
        let mouseLocation = NSEvent.mouseLocation

        // Create or update window
        if window == nil {
            createWindow()
        }

        guard let window = window else { return }

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
            self?.dismiss()
        }
    }

    private func createWindow() {
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

        window = panel
    }

    private func dismiss() {
        guard let window = window else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
        })
    }
}
