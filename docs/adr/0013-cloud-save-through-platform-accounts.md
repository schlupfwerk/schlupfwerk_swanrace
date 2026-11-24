# 0013. Cloud save through each platform's own account

- **Status:** Proposed
- **Date:** 2026-11-24

## Context

Players must keep their progress (earned items, chosen customization, records,
settings) when they change devices. We do not want our own server or to store
personal data ([0009](0009-offline-first-no-ads-cosmetic-only.md)).

## Decision

Use the cloud save that each platform already offers, tied to the account the
player already has:

| Platform | Cloud save | Account |
|---|---|---|
| Android | Google Play Games Saved Games | Google |
| iOS and macOS (App Store) | iCloud / Game Center saved games | Apple |
| Steam (Windows, Linux, macOS) | Steam Cloud | Steam |

- On Steam the player does **not** sign in with Google or Apple; Steam Cloud
  syncs the save file automatically.
- The **local save is the source of truth** and the game always works offline.
  Sync happens when online.
- Conflicts are resolved by **merging**, not by picking one file: union of
  earned items, best score per track, most recent settings and customization.
- The save format has a version number so it can be migrated.
- All of this lives behind the `Services` layer
  ([0007](0007-platform-services-layer.md)).

## Consequences

- Changing phones keeps progress **within the same ecosystem**: Android to
  Android, iPhone to iPhone/Mac, PC to PC/Steam Deck.
- Moving **between ecosystems** (Android to iPhone, phone to Steam) does not
  carry progress. Solving that needs [0014](0014-unified-account-deferred.md).
- We store no personal data ourselves; the save lives in the player's own
  Google, Apple or Steam account.
