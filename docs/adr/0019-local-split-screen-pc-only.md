# 0019. Local split-screen multiplayer, PC only

- **Status:** Proposed
- **Date:** 2026-11-26

## Context

Playtests with family showed that racing on the same couch is a big part of
the fun. On Steam, Remote Play Together also lets friends join a local
multiplayer game over the internet, with no netcode and no studio server, so
the privacy promise ([0009](0009-offline-first-no-ads-cosmetic-only.md), [0018](0018-crash-reports-without-sdk-no-push.md))
holds.

On phones it doesn't work: the screen is too small to split, there is one
touch surface, and phones rarely have several controllers attached.

## Decision

- **Split screen exists only on PC** (Windows, Linux/SteamOS, macOS; see
  [0011](0011-desktop-platforms-windows-linux-macos.md)). Phones and tablets
  never show the option.
- **Phase 1: 2 players**, the screen split in two. **Phase 2: 3 and 4
  players** in quadrants.
- Each player is bound to one device on a "press A to join" screen. The
  keyboard counts as one player. Bots fill the rest of the grid.
- One camera and one HUD per player; the podium shows every player.
- Graphics quality drops automatically in split screen.
- **A controller that disconnects mid-race** (flat battery, cable pulled)
  doesn't pause or end the race. A bot takes over that swan at once:
  - its view stays on screen as it is, with a **"CPU playing"** notice on that
    player's part of the screen;
  - the bot plays at a fixed **medium** skill (0.65, the middle of the medium
    range in `race.gd`), whatever the race difficulty, with no rubber band;
  - it doesn't learn or copy how that player drove. Whatever place it gets is
    that player's result.
- Still to decide before phase 1 is accepted: how a device stays bound to a
  player, and whether a reconnected controller can take the swan back.

## Consequences

- `race.gd` assumes a single player, HUD and camera today; that has to become
  a list.
- Each extra viewport costs GPU; the automatic quality drop must keep the
  game smooth on modest PCs and the Steam Deck.
- Swapping a player's brain for a `BotBrain` mid-race must work, which the
  brain/intent split ([0005](0005-unified-input-and-brains.md)) is meant to
  allow; check it when phase 1 starts.
- A dead battery never forces the players to quit the race.
- Mobile builds don't change.
