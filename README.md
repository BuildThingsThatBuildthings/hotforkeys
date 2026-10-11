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

The build creates `HotForKeys-local.zip`, a verified, ad-hoc signed development
bundle. Packaging uses Python 3's standard library and macOS `codesign`; no
certificate, keychain identity, timestamp service, or network access is needed.

The complete app is assembled and signed in a private `/tmp` directory. The ZIP
stores sorted entries, fixed timestamps, and explicit executable modes, without
filesystem extended attributes. Packaging identical executable and Info.plist
inputs with the same toolchain produces identical archive bytes. Each package is
verified before archiving and after extracting both the staged and delivered ZIP.

Keep the ZIP as the delivery artifact in Documents. File providers can add Finder
metadata to loose `.app` directories and invalidate strict signature verification.
The extraction command creates a fresh private directory outside those locations:

```bash
python3 scripts/package.py extract HotForKeys-local.zip
```

It prints the verified `/tmp/hotforkeys-local-.../HotForKeys.app` path and leaves
that copy available. It does not launch or install the app, request Accessibility
permission, or change security settings. Temporary locations are not permanent
storage; the ZIP can recreate the app whenever needed.

Build arguments are forwarded to SwiftPM. For a checkout in a file-provider folder
such as Documents, use a local scratch directory if test-bundle signing reports
Finder metadata:

```bash
./build.sh --scratch-path /tmp/HotForKeys-build --jobs 2
swift test --scratch-path /tmp/HotForKeys-build --jobs 2
```

The tests exercise modifier timing and shortcut lookup without launching the app,
installing global event monitors, or requiring Accessibility permission.

After building, test deterministic packaging, delivery verification, and detection
of a changed Info.plist (use the same scratch path as the build):

```bash
python3 -B scripts/test_packaging.py \
  --binary "$(swift build -c release --show-bin-path --scratch-path /tmp/HotForKeys-build)"/HotForKeys \
  --archive HotForKeys-local.zip
```

## Usage

1. Extract the development ZIP, then manually launch the printed `HotForKeys.app` path when ready
2. Grant Accessibility permissions when prompted (System Settings → Privacy & Security → Accessibility)
3. Hold any modifier key to see available shortcuts for the current app
4. Click the keyboard icon in the menu bar to toggle or quit

Scroll the overlay while holding a modifier to see all menu entries. The badge
shows the held modifiers; the list shows all available menu shortcuts. Menus are
refreshed on each new hold. Applications that do not expose their menus may show
an empty list.

## Release validation

The original project workflow is a local build followed by manually copying
`HotForKeys.app` to `/Applications`. This workflow now extracts the app from the
verified ZIP first; installation and launch remain explicit user actions. No
App Store release configuration is provided.

Ad-hoc bundle verification checks integrity; it does not establish Gatekeeper
approval, a Developer ID identity, or notarization. Before distributing a
candidate, manually verify menu reading,
scrolling, rapid release/repress, app switching, popup display, and disabling the
app in an explicitly approved Accessibility session. Check the oldest supported
macOS version and each intended CPU architecture. If direct distribution to other
users is chosen, Developer ID signing, notarization, distribution packaging, and
publication approval are separate steps. App Store distribution would require a
separate plan and is not assumed here.

## License

MIT
