# Architecture Decision Records

Short records of the important decisions in Swan Race: what was decided, why,
and what it costs. One file per decision, numbered in order.

- To propose a decision, copy [`template.md`](template.md) to the next number
  and open a pull request.
- Accepted ADRs are not rewritten. To change a decision, write a new ADR that
  supersedes the old one and update the old one's status.

| ADR | Title | Status |
|---|---|---|
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted |
| [0002](0002-godot-4-gdscript-single-project.md) | Godot 4 and GDScript in a single project | Accepted |
| [0003](0003-mobile-renderer.md) | Mobile renderer | Accepted |
| [0004](0004-platforms-android-ios-steam.md) | Platforms: Android, iOS and PC (Steam) | Superseded by 0011 |
| [0005](0005-unified-input-and-brains.md) | Unified input through brains and intents | Accepted |
| [0006](0006-handwritten-arcade-physics.md) | Handwritten, deterministic arcade physics | Accepted |
| [0007](0007-platform-services-layer.md) | Platform services behind an abstraction layer | Accepted |
| [0008](0008-skins-by-recolor.md) | Skins by recolor | Superseded by 0015 |
| [0009](0009-offline-first-no-ads-cosmetic-only.md) | Offline first, no ads, cosmetic-only monetization | Partly superseded by 0012 |
| [0010](0010-licensing.md) | Licensing: GPLv3 with app store exception, CC BY-NC-SA assets | Accepted |
| [0011](0011-desktop-platforms-windows-linux-macos.md) | Desktop platforms on Steam: Windows, Linux/SteamOS and macOS | Accepted |
| [0012](0012-no-paid-items.md) | No paid items: cosmetics are earned in the game | Accepted |
| [0013](0013-cloud-save-through-platform-accounts.md) | Cloud save through each platform's own account | Proposed |
| [0014](0014-unified-account-deferred.md) | Unified account across platforms | Deferred |
| [0015](0015-swan-customization-and-equal-abilities.md) | Swan customization by colors and accessories; equal abilities | Accepted |
