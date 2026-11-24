# 0015. Swan customization by colors and accessories; equal abilities

- **Status:** Accepted
- **Date:** 2026-11-24
- **Supersedes:** [0008](0008-skins-by-recolor.md)

## Context

[0008](0008-skins-by-recolor.md) planned skins as a mask texture plus a color
palette. The swan is now a simple cartoon model (swan mixed with ostrich) built
from smooth primitives, and players want to dress it: feather colors, legs and
accessories. Cosmetics are earned, not sold ([0012](0012-no-paid-items.md)).

## Decision

- `SwanLook` is pure data: nickname, feather style (**solid** or **gradient**),
  feather colors, leg color, and worn accessories as `id -> color`.
- Feathers use `shaders/feather.gdshader` (toon shading, solid color or vertical
  gradient over the whole swan). Other parts use toon materials.
- Accessories (**cap, wig, makeup, jacket, sneakers**) are simple meshes already
  in the model, shown or hidden and recolored. No new texture or model per item.
  Accessory ids are stable and never renamed.
- Colors come from a fixed palette chosen with left/right, so customization
  works on a controller without a mouse.
- Every swan has a **nickname** (up to 16 characters, with a random option).
- **All swans have exactly the same abilities.** Looks never change movement.
  Bot personalities change only how they drive.

## Consequences

- New items are cheap: a few primitives and an id.
- The model's shapes must leave room for accessories (head, body, feet).
- Final art may replace the primitives later, but must keep the same parts and
  accessory ids.
