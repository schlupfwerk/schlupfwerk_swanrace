# 0024. Sidereal Circuit: loop courses, bridges and falling into space

- **Status:** Accepted
- **Date:** 2026-11-26

## Context

The owner asked for a fourth map: a figure-8 circuit in space, with laps,
about 1:40 to 2:00 a lap, passing over itself. Space has no water to drown in,
so leaving the track needs its own rule: the swan screams and falls for about
3 seconds, then comes back like after drowning. He also asked for holes in the
track (the same fall) and asteroids to jump, and no low walls at the edges.

The island's code works on one flat loop and can't pass over itself
(`IslandTrack.locate` with no hint would mix the two levels). The courses of
[0022](0022-point-to-point-courses-and-skiing.md) already keep every search
near the swan's last known sample.

## Decision

1. **Courses can be loops.** `CourseTrack.build_loop(outline)` resamples a
   closed outline; `looped` makes indices and distances wrap around, the
   start line is at distance 0, and `CourseTracker` counts laps (halfway
   checkpoint, like `LapTracker`). `course_race.gd` runs laps from the
   settings, the final-lap music and the best lap record on loops, and the
   single run on the other courses. Maps say whether they are courses and
   whether they have laps (`Maps.LIST`); the laps setting is on only for maps
   with laps.
2. **Bridges come free:** heights are per distance along the course, and all
   searches stay near the swan's last sample, so the level above and the one
   below never mix.
3. **Falling** (`open_edges` courses, `CourseRules`): past an edge (with 0.2 m
   of grace), or on the ground over a hole, the swan falls: it stops, drops
   straight down faster and faster, tumbling and flailing, with a scream
   (`Sfx.scream`, synthesized), for 3 s (`Swan.fall`, same timer and comeback
   as drowning). It comes back on the center line (off an edge) or just past
   the hole, blinking. The player sees "Careful not to fall into space!!".
4. **Sidereal Circuit** (`SiderealCircuit`, `SiderealScenery`): a lemniscate
   of 1,355 m, 14 m wide, no walls. One crossing is a bridge 9 m up (110 m
   ramps, about 8%), the other passes under it. Seven holes (3.5 m long, 5 to
   8 m wide, against one edge or in the middle, so there is always a way
   around) and sixteen low asteroids (jump them or go around). Starry sky
   with nebulas, a deck with glowing edges and a dashed line, glowing rims
   around the holes, planets (one with rings), a bright star and rocks
   drifting far away.
5. Bots steer around holes and asteroids (and jump holes, sometimes), so
   they fall now and then too.

## Consequences

- Loops are now possible for later maps without touching the island.
- Hard edges with no walls: on easy mode kids may fall more often. The owner
  chose no walls; easy-mode walls are an option for later.
- Untested when written: check the lap time (~1:50), the bridge, the falls and
  the sky on both renderers.
