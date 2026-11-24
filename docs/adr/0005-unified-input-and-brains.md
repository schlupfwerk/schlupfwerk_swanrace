# 0005. Unified input through brains and intents

- **Status:** Accepted
- **Date:** 2026-11-24

## Context

Players use touch buttons, phone tilt, keyboard or controllers (Xbox,
PlayStation, generic Bluetooth controllers on phones). Bots and, later, online
players must drive swans exactly like a local player.

## Decision

- Each swan receives an **intent** every frame (`steer`, `accel`, `brake`,
  `jump`) from a **brain**: `PlayerInput`, `BotBrain` and later
  `NetworkInput`. Race logic never reads input devices directly.
- `PlayerInput` reads the Input Map actions `steer_left`, `steer_right`,
  `accel`, `brake` and `jump`. Keyboard, controller, touch buttons and tilt
  all feed these same actions. Triggers and sticks are analog.
- All input methods are active at the same time. The UI follows the **last
  input used**: controller input hides the touch buttons and shows controller
  glyphs (Xbox or PlayStation); touching the screen shows the buttons again.
  Connecting or disconnecting a controller mid-race never breaks the game.
  A setting can keep the touch buttons always visible.

## Consequences

- Bots are fair by construction and easy to swap for online players.
- Menus must be fully navigable with UI focus, not only by touch or mouse.
- Generic controllers may have unusual mappings; they need real-device tests.
