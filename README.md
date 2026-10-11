# HotForKeys

A macOS menu bar app that displays keyboard shortcuts for the active application when you press modifier keys.

## Features

- Shows available keyboard shortcuts as an overlay when holding modifier keys (⌘, ⌥, ⌃, ⇧)
- Lives in your menu bar for easy access
- Toggle on/off from the menu bar icon
- Reads shortcuts that applications expose through macOS Accessibility

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permissions (required to monitor keyboard events)

## Building

```bash
# Clone the repository
git clone https://github.com/BuildThingsThatBuildthings/hotforkeys.git
cd hotforkeys

# Build the app
./build.sh
```

The built app will be located at `HotForKeys.app`.

Build arguments are forwarded to SwiftPM. For a checkout in a file-provider folder
such as Documents, use a local scratch directory if test-bundle signing reports
Finder metadata:

```bash
./build.sh --scratch-path /tmp/HotForKeys-build --jobs 2
swift test --scratch-path /tmp/HotForKeys-build --jobs 2
```

The tests exercise modifier timing and shortcut lookup without launching the app,
installing global event monitors, or requiring Accessibility permission.

## Usage

1. Launch `HotForKeys.app`
2. Grant Accessibility permissions when prompted (System Settings → Privacy & Security → Accessibility)
3. Hold any modifier key to see available shortcuts for the current app
4. Click the keyboard icon in the menu bar to toggle or quit

Scroll the overlay while holding a modifier to see all menu entries. The badge
shows the held modifiers; the list shows all available menu shortcuts. Menus are
refreshed on each new hold. Applications that do not expose their menus may show
an empty list.

## Release validation

`./build.sh` creates a local app bundle; it does not prepare a signed, notarized
distribution. Before distributing a candidate, manually verify menu reading,
scrolling, rapid release/repress, app switching, popup display, and disabling the
app in an explicitly approved Accessibility session. Check the oldest supported
macOS version and each intended CPU architecture. Developer ID signing,
notarization, packaging, and publication approval are separate release steps.

## License

MIT
