import SwiftUI

struct OverlayView: View {
    let shortcut: Shortcut

    var body: some View {
        VStack(spacing: 4) {
            // Main shortcut display
            Text(shortcut.displayString)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Action name (if available)
            if let actionName = shortcut.actionName {
                Text(actionName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        OverlayView(shortcut: Shortcut(key: "V", modifiers: .command, actionName: "Paste"))
        OverlayView(shortcut: Shortcut(key: "Z", modifiers: [.command, .shift], actionName: "Redo"))
        OverlayView(shortcut: Shortcut(key: "F", modifiers: [.command, .control], actionName: "Enter Full Screen"))
    }
    .padding()
    .background(Color.gray)
}
