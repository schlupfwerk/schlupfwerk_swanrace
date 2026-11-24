# 0003. Mobile renderer

- **Status:** Accepted
- **Date:** 2026-11-24

## Context

The main audience plays on ordinary phones. Godot 4 offers the Forward+,
Mobile and Compatibility renderers.

## Decision

Use the **Mobile** renderer on every platform, with low poly models and
compressed textures (ETC2/ASTC enabled).

## Consequences

- Good performance on mid-range phones; the same look on PC and Steam Deck.
- Some advanced effects of Forward+ are unavailable. The art style must not
  depend on them.
- Very old devices without Vulkan support may not run the game. If that turns
  out to matter, a new ADR can evaluate the Compatibility renderer.
