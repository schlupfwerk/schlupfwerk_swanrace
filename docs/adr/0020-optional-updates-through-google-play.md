# 0020. Optional updates through Google Play

- **Status:** Accepted
- **Date:** 2026-11-26

## Context

Players on old versions keep bugs that are already fixed. We want to nudge
them to update when a newer version is in the store.

The game is offline and the APK asks for no permissions
([0009](0009-offline-first-no-ads-cosmetic-only.md),
[privacy audit](../privacy-audit.md)). A check of our own (the game asking
schlupfwerk.com for the latest version) would need the internet permission and
would send the player's IP to us, so it is ruled out.

Google Play offers **in-app updates** (Play Core `app-update` library): the
game asks the Play Store app on the phone whether an update exists. The Play
Store does the network work, not the game. There are two modes: *immediate*
(a full-screen "update to continue") and *flexible* (download in the
background, restart later).

## Decision

- **Updates are optional, never forced.** We use only the **flexible** mode.
  The immediate mode is not used, whatever priority a release has.
- The check runs when the game opens, on the menu, **never during a race**.
  If an update exists, Google's dialog offers it; the player may say no and
  plays on.
- A player who declines is asked again only when a newer version appears
  (the declined version code is kept in `settings.cfg`).
- After the download, the menu offers "restart to update"; nothing restarts
  by itself.
- No Play Store, no connection, or an APK installed by hand: the check fails
  silently and the game works as usual.
- It is a small Android plugin of our own (Kotlin, Godot Android plugin v2)
  behind the services layer ([0007](0007-platform-services-layer.md)), with a
  fake implementation on PC.
- The dialog is Google's own and leaves no link to a web page or store page,
  so it doesn't go through `ParentalGate`.
- **Other platforms:** Steam updates games by itself; on iOS the App Store
  updates apps automatically, and there is nothing to add for now.

## Consequences

- Players on old versions can stay there; accepted by design.
- Before it ships: confirm on the exported APK (`aapt2 dump xmltree`) that no
  permission was added, and list the Play Core library in the
  [privacy audit](../privacy-audit.md).
- Only installs from Google Play (including test tracks) see the prompt;
  test it with internal app sharing or a test track.
