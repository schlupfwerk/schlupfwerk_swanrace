# Privacy audit: what the game sends and stores

Swan Race promises **no ads and no selling data** ([ADR 0009](adr/0009-offline-first-no-ads-cosmetic-only.md),
[ADR 0018](adr/0018-crash-reports-without-sdk-no-push.md)). The only data it will send is anonymous
error and usage reports to Google Analytics, without any SDK; that is planned, not built yet.
This file checks that promise against the code. Update it whenever a package,
SDK or network feature is added, and before filling in any store privacy form.

- **Last checked:** 2026-11-25, version 0.0.8 (Windows alpha and Android test build)
- **Result:** the game sends nothing. Nothing calls home.

## What calls home

| Package or code | Calls home? | Notes |
|---|---|---|
| Godot 4.7.2 engine (official export template) | No | No telemetry or crash reporting in the engine |
| Game scripts (`scripts/`) | No | No `HTTPRequest`, `HTTPClient`, sockets, WebSocket or multiplayer anywhere |
| `addons/build_info` | No | Runs only in the editor, at export time |
| Store or platform SDKs (Google Play Games, Game Center, Steam, Firebase) | Not integrated | See "Before adding a service". Firebase is ruled out ([ADR 0018](adr/0018-crash-reports-without-sdk-no-push.md)) |
| Google Analytics 4 (Measurement Protocol, from GDScript) | Planned, not built | Anonymous errors and basic usage only; no SDK ([ADR 0018](adr/0018-crash-reports-without-sdk-no-push.md)) |

## Outside the game process

| What | When | Leaves the device? |
|---|---|---|
| `OS.shell_open` to `https://schlupfwerk.com/<lang>` (`scripts/ui/home.gd`) | Only when the player presses "Site da Schlupfwerk" in the About tab and an adult passes the parental gate (`scripts/ui/parental_gate.gd`) | Opens the browser; the game sends nothing |
| `git` (`scripts/core/game_version.gd`) | Editor only (`OS.has_feature("editor")`), never in an exported build | No |
| PowerShell `Get-CimInstance Win32_VideoController` (`scripts/save/settings.gd`) | Windows, when the Video settings list the GPUs | No, it only counts the local GPUs |

## Stored on the player's device only

All under `user://` (on Windows, `%APPDATA%\Godot\app_userdata\Swan Race`).

| File | Contents |
|---|---|
| `profile.cfg` | Characters (nicknames, looks) and lap records |
| `settings.cfg` | Settings, including a chosen GPU name |
| `music_*.wav` | Music the game renders once and caches |
| `logs/` | Godot logs (up to 1000 files): GPU name, folder paths, errors |

None of these are uploaded. Nicknames are typed by the player and stay local.

## Store privacy forms (current answers)

- **Google Play, Data safety:** no data collected, no data shared.
- **Android APK:** requests no permissions at all (not even internet); checked with
  `aapt2 dump xmltree` on the 0.0.8 build.
- **Apple, App Privacy:** Data Not Collected.
- **Steam:** no third-party accounts or data collection to disclose.

These answers change as soon as any service in the next section ships. When Google Analytics ships:
Google Play declares anonymous app activity and diagnostics (not shared, not used for ads), the APK asks
for the internet permission, and Apple App Privacy declares diagnostics and usage data not linked to the user.

## Before adding a service

Firebase, Google Play Games, Game Center, Steam, cloud saves or crash reporting
all send data. Crashes come from the Play Console (Android vitals and
pre-launch reports), errors and basic usage from anonymous Google Analytics
without an SDK, and there are no push notifications
([ADR 0018](adr/0018-crash-reports-without-sdk-no-push.md)). Before any of
them ships:

1. Write an ADR, and update the privacy page on schlupfwerk.com (site ADRs 0007 and 0010).
2. Make it opt-in where the store allows (Google Analytics stays anonymous, as
   [ADR 0018](adr/0018-crash-reports-without-sdk-no-push.md) describes).
3. Add it to "What calls home" above and redo the store forms.

## External links

ADR 0009 allows no external link without a parental check, and the stores
require one in apps for children. Every link that leaves the game goes through
`ParentalGate` (a multiplication with three answers; works with a controller).
Today that is only the studio site in the About tab.
