# 0021. Free forever: no purchases, not even a tip

- **Status:** Accepted
- **Date:** 2026-11-26
- **Supersedes:** the tip in [0012](0012-no-paid-items.md)

## Context

[0012](0012-no-paid-items.md) kept an optional in-game **tip** as the only
purchase and left the revenue model open ("game price and/or tips"). The studio
site now says Swan Race is **completely free, with no purchases**, and the owner
decided that the game will never make money: no price, no transactions, no
microtransactions. The studio's paid games are separate, closed-source games
(site ADR 0010).

## Decision

- **Swan Race is free forever.** No price, no in-game purchases, no tip.
- Everything stays **unlocked or earned by playing** ([0012](0012-no-paid-items.md),
  [0015](0015-swan-customization-and-equal-abilities.md)).
- Support for the studio stays **outside the game**: the coffee page on
  schlupfwerk.com (Ko-fi and Pix). The game links only to the studio site,
  behind the parental gate.
- No `Store` layer: there is nothing to sell.

## Consequences

- No StoreKit, Google Play Billing or Steam microtransactions to integrate,
  test or declare.
- The game, the README and the site say the same thing: free, with no purchases.
- The game earns nothing directly, accepted by design.
