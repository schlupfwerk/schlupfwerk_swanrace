# 0001. Record architecture decisions

- **Status:** Accepted
- **Date:** 2026-11-24

## Context

The project is open source and will have contributors (and AI assistants) who
were not present when decisions were made. Without a record, decisions get
re-argued or silently broken.

## Decision

Keep lightweight Architecture Decision Records in `docs/adr/`, one Markdown
file per decision, using [`template.md`](template.md). `CLAUDE.md` stays the
short, current summary; ADRs hold the reasoning.

## Consequences

- Every significant change of direction needs a new ADR in its pull request.
- Old ADRs are superseded, never rewritten.
