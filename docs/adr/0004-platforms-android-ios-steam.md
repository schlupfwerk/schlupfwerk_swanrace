# 0004. Platforms: Android, iOS and PC (Steam)

- **Status:** Superseded by [0011](0011-desktop-platforms-windows-linux-macos.md)
- **Date:** 2026-11-24

## Context

The game was planned for phones. Since it is tested on the PC anyway and Godot
exports to desktop from the same project, PC costs little extra.

## Decision

- Targets: **Android**, **iOS** and **PC through Steam** (Windows first,
  Linux/Steam Deck when possible). No web version.
- Phones remain the main focus. Order: Android prototype (Samsung S23), then
  iOS when a Mac is available, then Steam after the prototype.

## Consequences

- Controller support and menus navigable without touch become requirements
  (see [0005](0005-unified-input-and-brains.md)).
- A Steamworks implementation is needed in the services layer
  (see [0007](0007-platform-services-layer.md)), plus the Steam Direct fee.
- iOS builds require a Mac with Xcode (or a macOS CI runner).
