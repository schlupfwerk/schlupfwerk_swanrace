# 0012. No paid items: cosmetics are earned in the game

- **Status:** Accepted; the tip superseded by [0021](0021-free-forever-no-purchases.md)
- **Date:** 2026-11-24
- **Supersedes:** the monetization part of [0009](0009-offline-first-no-ads-cosmetic-only.md)

## Context

Paid skins would need purchases synced across stores, which needs our own
account server and personal data (see [0014](0014-unified-account-deferred.md)).
That conflicts with "no data collection" in a game for children.

## Decision

- **No paid skins or items.** Cosmetics (skins, later accessories) are
  **earned by playing**.
- The optional **tip** stays, as the only purchase. It unlocks nothing.
- Skins are still made by recolor ([0008](0008-skins-by-recolor.md)) and every
  item has a **stable id** that never changes, so saves stay valid.

## Consequences

- No receipt validation, no refunds of items, no cross-store entitlements.
- The `Store` layer shrinks to the tip only.
- Revenue comes from the game price and/or tips; the exact model is open.
