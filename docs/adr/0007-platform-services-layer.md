# 0007. Platform services behind an abstraction layer

- **Status:** Accepted
- **Date:** 2026-11-24

## Context

Leaderboards, achievements, cloud saves and purchases work differently on each
platform: Game Center and StoreKit, Google Play Games and Play Billing,
Steamworks.

## Decision

Game code talks only to two interfaces:

- `Services`: leaderboards, achievements and cloud save
- `Store`: skin purchases and the optional tip

Each has an implementation for iOS, Android and Steam (through the
**GodotSteam** plugin), plus a **fake** one for development on the PC. No
Steam DRM is required.

## Consequences

- The game runs and is testable with no platform account or network.
- Every new platform feature must be added to all implementations or degrade
  gracefully.
