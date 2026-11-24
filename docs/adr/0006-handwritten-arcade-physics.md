# 0006. Handwritten, deterministic arcade physics

- **Status:** Accepted
- **Date:** 2026-11-24

## Context

The fun of the game lives in the transitions between terrains, especially the
take-off from water. That needs precise, tunable control. A future online
mode benefits from predictable simulation.

## Decision

Swan movement (position, speed, height) is written by hand as simple arcade
rules per terrain. The physics engine is not used to move swans; it may be used
for overlap checks and scenery.

## Consequences

- Full control over feel and tuning; behavior is the same on every device.
- We must write and test our own movement code, including collisions with
  obstacles.
- Logic stays separate from visuals, so it can run in tests or on a server.
