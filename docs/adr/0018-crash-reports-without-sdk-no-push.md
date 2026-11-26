# 0018. Crash reports from Google Play first; no push notifications

- **Status:** Accepted
- **Date:** 2026-11-26

## Context

With the Android build in testing, we need to know which phones crash or
freeze. Firebase (Crashlytics for crashes, Cloud Messaging for push
notifications) was considered.

The game promises "no ads, no tracking" ([0009](0009-offline-first-no-ads-cosmetic-only.md),
site ADR 0007), and its audience includes children (LGPD art. 14, COPPA, the
stores' family rules). Today the APK asks for no permissions, not even
internet, and every store form says "no data collected"
([privacy audit](../privacy-audit.md)).

What each option would mean:

- **Crashlytics** sends stack traces, device model, Android version, memory
  state and a **persistent installation ID**. A persistent ID is personal data
  under the LGPD and COPPA, even without a name. The Play Data safety form would
  change to "collected: crash logs, diagnostics, device IDs", and the APK would
  need the internet permission. Godot 4 has no official Firebase plugin, and
  Crashlytics only sees native crashes (it needs the NDK module and symbol
  upload). GDScript errors don't crash the app, so they would only show up if we
  sent each one as a non-fatal error by hand.
- **Firebase Analytics** (how players use the game: screens, race time, where
  they quit) is analytics and breaks the "no tracking" promise.
- **Push notifications** need an FCM token (another identifier), the
  `POST_NOTIFICATIONS` permission on Android 13+ and someone to send them. The
  game is free, offline and has no online events, so a push could only call the
  player back into the game, which is what family rules and parents' trust
  argue against.
- **Google Play Console** already shows crashes and ANRs per device model and
  Android version (**Android vitals**), from players who allowed their phone to
  share diagnostics with Google. Uploading a build to a test track also runs it
  on real phones (**pre-launch report**). Neither needs an SDK in the game.

## Decision

1. **Crash reports come from the Play Console first:** Android vitals and the
   pre-launch report on every test build. No SDK, no permission; the game still
   sends nothing.
2. **Crashlytics only if that is not enough**, and then only:
   - Crashlytics alone: **no Firebase Analytics, no advertising ID**;
   - **off by default**, turned on by the player in Settings (opt-in);
   - after a new ADR that supersedes this point, an update to the privacy page
     on schlupfwerk.com, the [privacy audit](../privacy-audit.md) and the store
     forms, all before the build ships.
3. **No analytics** of how players use the game.
4. **No push notifications.** To be reconsidered only if an online feature
   gives a real reason (e.g. a friend's invitation in multiplayer 2.0), with
   its own ADR.

## Consequences

- The promise and the store forms stay as they are: no data collected, no
  permissions.
- Play vitals only covers players who share diagnostics with Google and
  installs from Google Play; it does not cover sideloaded APKs or PC builds.
- GDScript errors that don't crash the game stay invisible; test builds on
  real phones and Godot logs remain the way to find them.
- No re-engagement through notifications, accepted by design.
