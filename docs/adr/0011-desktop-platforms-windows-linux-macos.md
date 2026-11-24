# 0011. Desktop platforms on Steam: Windows, Linux/SteamOS and macOS

- **Status:** Accepted
- **Date:** 2026-11-24
- **Supersedes:** [0004](0004-platforms-android-ios-steam.md)

## Context

[0004](0004-platforms-android-ios-steam.md) planned Steam on Windows only. Godot
exports to Windows, Linux and macOS from the same project, and GodotSteam
supports all three.

## Decision

- Targets: **Android**, **iOS**, and on **Steam**: **Windows**, **Linux/SteamOS**
  (Steam Deck) and **macOS**. No web version. Phones remain the main focus.
- Ship a native Linux build (do not rely only on Proton) and aim for **Steam
  Deck Verified**: full controller support, readable text on a 7" screen, no
  keyboard required.
- Order: Android prototype (Samsung S23); then Windows + Linux when the game
  goes to Steam; macOS together with iOS, when a Mac is available.

## Consequences

- macOS builds must be signed and notarized, which needs a Mac and an Apple
  Developer account, the same requirements as iOS.
- Each desktop OS needs real tests before release (a Steam Deck covers Linux).
