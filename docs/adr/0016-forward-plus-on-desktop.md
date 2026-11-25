# 0016. Forward+ renderer on desktop, Mobile on phones

- **Status:** Accepted
- **Date:** 2026-11-25
- **Supersedes:** [0003](0003-mobile-renderer.md)

## Context

[0003](0003-mobile-renderer.md) chose the Mobile renderer everywhere. On PC the
game runs far above the refresh rate, but edges stay jagged where MSAA does not
help (outlines, feathers, lashes, foam), and the Mobile renderer has no temporal
antialiasing (TAA) or ambient occlusion (AO). Godot can pick the renderer per
platform in `project.godot`.

## Decision

- **Desktop (Windows, Linux/SteamOS, macOS): Forward+.** **Phones: Mobile**
  (`rendering_method.mobile`), as before.
- Quality presets add screen-space smoothing (FXAA from Medium up) and, on
  Forward+ only, AO (High and Ultra) and TAA (Ultra). A new **Ultra** preset
  renders the 3D scene at 150% and scales it down (supersampling).
- On Forward+ the sun is smaller and the shadow blur and ambient light lower,
  so the look matches the Mobile renderer instead of turning hazy with blurred
  shadows. These values live in `Settings.configure_sun` and
  `Settings.configure_environment`.
- Swans get 1.6× more segments on round parts with high scenery detail (the PC
  default). Phones start on Medium and keep the old geometry.

## Consequences

- Smoother image on PC; phones cost the same as before (measured on an RTX 5060
  at 1600×900: High about 5 to 7 ms per frame, Ultra about 9 to 13 ms).
- Two renderers to check: any visual change must be looked at in both
  (`--rendering-method mobile` runs the Mobile renderer on PC).
- Very weak PCs may need the Low preset; Forward+ costs more than Mobile.
- Per-device quality on phones (choosing the preset by model) is still to do,
  together with the mobile builds.
