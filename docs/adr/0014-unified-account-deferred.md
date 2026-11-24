# 0014. Unified account across platforms (deferred)

- **Status:** Deferred
- **Date:** 2026-11-24

## Context

With [0013](0013-cloud-save-through-platform-accounts.md), progress does not move
between ecosystems (Android, Apple, Steam). If that becomes important, or if
paid items ever come back, we need a single account across platforms.

## Idea for the future

Our own backend with:

```
Account (internal id)
 ├─ Linked identities: Google Play Games id, Game Center id, Steam id
 ├─ Orders: store, receipt/transaction id, price, currency, date, status
 └─ Entitlements: item ids the player owns
```

- Sign in with the platform account and link the others; no email or password.
- Items are not downloaded: they are already in the game (recolor), the server
  only says which are unlocked. The list is cached locally for offline play.
- Receipts validated server-side with Apple, Google and Steam; refunds revoke items.

## Why it is deferred

- It is personal data: privacy policy, store declarations, and parental consent
  for children (LGPD art. 14, COPPA).
- A server to run, secure and keep alive for years.
- Store rules on cross-platform items must be checked at the time.

Revisit when there are real players on more than one ecosystem asking for it.
