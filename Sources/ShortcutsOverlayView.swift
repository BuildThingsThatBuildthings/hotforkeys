import SwiftUI

struct ShortcutsOverlayView: View {
    let sections: [MenuSection]
    let activeModifiers: NSEvent.ModifierFlags

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 350), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header with active modifiers
            HStack(spacing: 8) {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                // Show active modifiers
                ModifierBadge(modifiers: activeModifiers)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.3))

            Divider()
                .background(Color.white.opacity(0.2))

            // Shortcuts grid
            ScrollView {
                if sections.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.4))
                        Text("No shortcuts available")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                        ForEach(sections, id: \.title) { section in
                            MenuSectionView(section: section)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(maxWidth: 900, maxHeight: 600)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.7))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 40, y: 10)
    }
}

struct ModifierBadge: View {
    let modifiers: NSEvent.ModifierFlags

    var body: some View {
        HStack(spacing: 4) {
            if modifiers.contains(.control) {
                KeyCap(symbol: "⌃")
            }
            if modifiers.contains(.option) {
                KeyCap(symbol: "⌥")
            }
            if modifiers.contains(.shift) {
                KeyCap(symbol: "⇧")
            }
            if modifiers.contains(.command) {
                KeyCap(symbol: "⌘")
            }
        }
    }
}

struct KeyCap: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

struct MenuSectionView: View {
    let section: MenuSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            Text(section.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1)

            // Shortcuts
            VStack(alignment: .leading, spacing: 4) {
                ForEach(section.shortcuts.prefix(12), id: \.displayString) { shortcut in
                    ShortcutRow(shortcut: shortcut)
                }

                if section.shortcuts.count > 12 {
                    Text("+ \(section.shortcuts.count - 12) more")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct ShortcutRow: View {
    let shortcut: Shortcut

    var body: some View {
        HStack(spacing: 12) {
            // Action name
            Text(shortcut.actionName ?? "Action")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)

            Spacer()

            // Keyboard shortcut
            HStack(spacing: 2) {
                ForEach(modifierSymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 18, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                        )
                }

                Text(shortcut.key.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.15))
                    )
            }
        }
        .padding(.vertical, 3)
    }

    private var modifierSymbols: [String] {
        var symbols: [String] = []
        if shortcut.modifiers.contains(.control) { symbols.append("⌃") }
        if shortcut.modifiers.contains(.option) { symbols.append("⌥") }
        if shortcut.modifiers.contains(.shift) { symbols.append("⇧") }
        if shortcut.modifiers.contains(.command) { symbols.append("⌘") }
        return symbols
    }
}

#Preview {
    let sampleSections = [
        MenuSection(title: "File", shortcuts: [
            Shortcut(key: "N", modifiers: .command, actionName: "New"),
            Shortcut(key: "O", modifiers: .command, actionName: "Open"),
            Shortcut(key: "S", modifiers: .command, actionName: "Save"),
            Shortcut(key: "S", modifiers: [.command, .shift], actionName: "Save As"),
            Shortcut(key: "W", modifiers: .command, actionName: "Close"),
        ]),
        MenuSection(title: "Edit", shortcuts: [
            Shortcut(key: "Z", modifiers: .command, actionName: "Undo"),
            Shortcut(key: "Z", modifiers: [.command, .shift], actionName: "Redo"),
            Shortcut(key: "X", modifiers: .command, actionName: "Cut"),
            Shortcut(key: "C", modifiers: .command, actionName: "Copy"),
            Shortcut(key: "V", modifiers: .command, actionName: "Paste"),
        ]),
        MenuSection(title: "View", shortcuts: [
            Shortcut(key: "F", modifiers: [.command, .control], actionName: "Enter Full Screen"),
            Shortcut(key: "+", modifiers: .command, actionName: "Zoom In"),
            Shortcut(key: "-", modifiers: .command, actionName: "Zoom Out"),
        ]),
    ]

    return ZStack {
        Color.gray
        ShortcutsOverlayView(sections: sampleSections, activeModifiers: .command)
    }
}
