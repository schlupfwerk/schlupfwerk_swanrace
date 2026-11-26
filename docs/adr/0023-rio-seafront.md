# 0023. Rio Seafront: an easy, flat point-to-point course

- **Status:** Accepted
- **Date:** 2026-11-26

## Context

The third map is Rio de Janeiro's seafront, described by the owner as an easy
run of about 2:30 along the whole beach: sea on the right, the city on the
left (Copacabana as the reference), flat, with people walking on the
seafront, logs, and small puddles to jump. It uses the point-to-point courses
of [0022](0022-point-to-point-courses-and-skiing.md).

## Decision

- **`RioCourse`**: 1.9 km from the start to the finish line along the gentle
  curve of a bay (about 70° in total, never sharp), flat, 18 m wide: the
  promenade on the left and the sand on the right. Laps are off (it is a
  course). Target ~2:30 at ~12.5 m/s.
- **Puddles** (new in `CourseTrack`, used by `CourseRules`): small, longer
  along the course than across. Jump them; running through one, the swan is
  wet and has half its top speed while in it. The "Jump!" alert and the bots
  see them like logs.
- **People** (`CourseMover`, new STROLL pattern) walk up and down the
  promenade; surfers cross it with a board. Solid like the animals in the
  Alps: running into one, the swan pops up past them, blinking.
- **`RioScenery`**: sea, beach with umbrellas, kiosks and volleyball nets,
  the wavy black-and-white promenade (a generated texture), coconut palms,
  the avenue, a row of apartment buildings, green hills behind and a round
  granite peak past the end of the bay. No real buildings, statues or brands.
- The course map draws each terrain in its own color (sand for Rio).

## Consequences

- Another map with no new movement: it should be the easiest one, good for
  kids on easy mode.
- Untested when written: check the time, the puddles' size and the people's
  walking on a playtest.
