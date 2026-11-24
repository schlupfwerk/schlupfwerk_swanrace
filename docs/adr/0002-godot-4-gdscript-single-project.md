# 0002. Godot 4 and GDScript in a single project

- **Status:** Accepted
- **Date:** 2026-11-24

## Context

The game targets several platforms and is made by a very small indie team.
Separate native apps (Kotlin for Android, Swift for iOS) would multiply the
work for every feature.

## Decision

- Use **Godot 4** (latest stable, standard build, not .NET) with **GDScript**.
- One project and one repository for every platform. Platforms differ only in
  their export presets.
- No Kotlin or Swift application code. Native code enters only as Godot
  plugins, if ever needed (Game Center, Play Games, Steamworks, purchases).

## Consequences

- One codebase, fast iteration with F5 on the PC, free and open source engine
  compatible with our GPLv3 code.
- We depend on Godot's export pipeline and on community plugins for platform
  services.
- GDScript follows the official Godot style guide (snake_case, tabs).
