# HotForKeys

A macOS menu bar app that displays keyboard shortcuts for the active application when you press modifier keys.

## Features

- Shows available keyboard shortcuts as an overlay when holding modifier keys (⌘, ⌥, ⌃, ⇧)
- Lives in your menu bar for easy access
- Toggle on/off from the menu bar icon
- Supports all standard macOS applications

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

## Usage

1. Launch `HotForKeys.app`
2. Grant Accessibility permissions when prompted (System Settings → Privacy & Security → Accessibility)
3. Hold any modifier key to see available shortcuts for the current app
4. Click the keyboard icon in the menu bar to toggle or quit

## License

MIT
