# 0017. Touch controls with automatic throttle

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

Swan Race is a family game, and on phones many players are young children.
The first touch layout (steer, accelerate, brake, jump, turbo, horn) asked for
too many buttons at once: holding accelerate made jumping or using turbo hard.
Menus were drawn for a 1280×720 screen, so on a phone their rows were only a
few millimeters tall.

## Decision

- **On touch there is no accelerate button.** The swan always speeds up by
  itself and eases off in sharp turns (`PlayerInput`). Holding brake slows it
  only while held; letting go speeds up again at once. Turbo still means full
  throttle.
- **Layout:** left thumb ◀ ▶; right thumb jump (largest), turbo above it,
  brake and horn beside; a menu button (two taps) next to the minimap. True
  multi-touch, and a finger may slide between buttons (`TouchControls`).
- The buttons show only while touch is the last input used (`InputGlyphs`); a
  controller or keyboard hides them and works as before, accelerate included.
- **Menus are 1.5× bigger on phones** (`Settings.apply_menu_scale`); long
  panels scroll. The race keeps 1.0, its buttons already sized for thumbs.
- The Android back button acts as `ui_cancel` (back inside the game).

## Consequences

- A child only steers, jumps and uses turbo.
- Speed control on touch is coarser than with triggers; brake is enough for
  this game.
- Any new menu screen must fit 853×480 virtual pixels (1280×720 / 1.5) or
  scroll.
