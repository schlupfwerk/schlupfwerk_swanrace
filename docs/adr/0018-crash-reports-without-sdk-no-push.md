# 0018. Errors from Google Play and anonymous Google Analytics; no SDK, no push

- **Status:** Accepted
- **Date:** 2026-11-26

## Context

With the Android build in testing, we need to know which phones crash or
freeze, and which errors players hit. Firebase (Crashlytics for crashes,
Analytics, Cloud Messaging for push notifications) was considered.

The game's audience includes children (LGPD art. 14, COPPA, the stores' family
rules). Today the APK asks for no permissions, not even internet, and every
store form says "no data collected" ([privacy audit](../privacy-audit.md)).

On 2026-11-26 the studio changed its promise from "no ads, no tracking" to
**"no ads, no selling data"** and allowed **Google Analytics, anonymous, as the
only data tool in the games** (site ADR 0010). The owner wants no Firebase, no
Crashlytics and no plugin or SDK that collects data.

What each option would mean:

- **Crashlytics** sends stack traces, device model, Android version, memory
  state and a **persistent installation ID**, which is personal data under the
  LGPD and COPPA. Godot 4 has no official Firebase plugin, and Crashlytics only
  sees native crashes; GDScript errors don't crash the app.
- **Firebase SDK (Analytics, Crashlytics, Messaging)** adds a large SDK that
  collects more than we need and is hard to keep anonymous.
- **Google Analytics 4 through the Measurement Protocol** is plain HTTPS from
  GDScript (`HTTPRequest`): no plugin, no SDK, and the game decides exactly what
  each event carries. It can also report GDScript errors, which no crash tool sees.
- **Push notifications** need an FCM token (another identifier), the
  `POST_NOTIFICATIONS` permission on Android 13+ and someone to send them. The
  game is free and offline, so a push could only call the player back into the
  game, which family rules and parents' trust argue against.
- **Google Play Console** already shows crashes and ANRs per device model and
  Android version (**Android vitals**), and runs test builds on real phones
  (**pre-launch report**). Neither needs anything in the game.

## Decision

1. **Crashes and ANRs come from the Play Console:** Android vitals and the
   pre-launch report on every test build.
2. **Errors and basic usage go to Google Analytics 4, through the Measurement
   Protocol, from GDScript.** No Firebase, no Crashlytics, no plugin or SDK.
   It must stay anonymous:
   - events only about the game: e.g. game started, race finished, an error
     happened (message and where), with device model, OS and game version;
   - **no name, nickname, email, contacts, precise location, advertising ID
     or user ID**; the `client_id` is a random value that the player can reset
     by clearing the game data;
   - no Google Signals, no ads personalization, no link to Google Ads;
   - nothing is sent without internet; nothing is queued in a way that changes
     how the game plays offline.
3. **Before the build that sends anything ships:** the internet permission is
   turned on in `export_presets.cfg`, the [privacy audit](../privacy-audit.md)
   and the store forms (Google Play Data safety, Apple App Privacy) are updated,
   and the Google Play Families policy is checked for analytics in a game that
   children may play.
4. **No push notifications.** To be reconsidered only if an online feature
   gives a real reason (e.g. a friend's invitation in multiplayer 2.0), with
   its own ADR.

## Consequences

- The privacy page on schlupfwerk.com already describes this (site ADR 0010).
- The store forms change from "no data collected" to anonymous app activity and
  diagnostics, and the APK will ask for the internet permission.
- We write and keep a small GA4 client in GDScript (a few events, one HTTPS
  request each), with the API secret in the export, not in the repository.
- Play vitals only covers players who share diagnostics with Google and
  installs from Google Play; Analytics also covers PC builds.
- No re-engagement through notifications, accepted by design.
