# 0010. Licensing: GPLv3 with app store exception, CC BY-NC-SA assets

- **Status:** Accepted
- **Date:** 2026-11-24

## Context

The project is open source but must ship on stores whose terms conflict with
the GPL, and the art should not be resold by others.

## Decision

- Code: **GPLv3** with an additional permission (`LICENSE-EXCEPTION.md`) for
  app stores and similar platforms (App Store, Google Play, Steam), provided
  the source stays available.
- Assets: **CC BY-NC-SA 4.0** (`ASSETS_LICENSE.md`). Third-party assets need
  an entry in `assets/CREDITS.md` with a compatible license.
- Name and logo are not licensed (`TRADEMARKS.md`).
- Commits are signed off (`git commit -s`, DCO).

## Consequences

- The repository must stay public for store releases.
- Signing keys and credentials must never be committed (blocked by
  `.gitignore`).
