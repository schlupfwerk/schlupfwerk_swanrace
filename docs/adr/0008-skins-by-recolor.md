# 0008. Skins by recolor

- **Status:** Superseded by [0015](0015-swan-customization-and-equal-abilities.md)
- **Date:** 2026-11-24

## Context

Skins are the main monetization. Making a new model or texture per skin is
expensive and makes the game heavier.

## Decision

A shader with a mask texture (body, wings, beak, details) recolors the swan
with a palette of 3 or 4 colors. Each skin is a data resource (id, name,
colors) with no new model or texture. Accessories (hat, scarf) may come later.

## Consequences

- New skins are cheap to make and add almost nothing to the download size.
- The swan model and its mask must be designed for recoloring from the start.
