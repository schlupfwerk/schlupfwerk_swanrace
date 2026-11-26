# 0022. Point-to-point courses, skiing, and the Swiss Alps

- **Status:** Accepted
- **Date:** 2026-11-26

## Context

The Desert Island is a circuit: laps, lap times, a lap counter. The next maps
(Swiss Alps, then Germany and Rio de Janeiro) are different: one run from a
start to a finish, with stretches of different terrain in a row. The Swiss
Alps start with a ski descent, which needs a new way of moving.

The island code (`IslandTrack`, `TrackRules`, `LapTracker`, `BotBrain`,
`race.gd`) is built around one closed loop: distances wrap around, the start
is also the finish, and many constants are the island's. It works and is
tuned. The new code is written without running the game, so it should not
risk breaking it.

## Decision

1. **Courses live next to the circuit, not inside it.** A point-to-point map
   is a `CourseTrack` subclass (center line built from curvature per meter,
   heights, widths and terrain per distance). Its own pieces mirror the
   island's: `CourseRules`, `CourseTracker` (no laps: distance to the
   finish), `CourseBotBrain`, `scenes/course_race.tscn` (`course_race.gd`) and
   `CourseMap` on the HUD. Swans, the motor, the model, the HUD, the camera
   and the podium are shared. The island is untouched except for small,
   optional hooks (HUD and arrow accept a course, speedometer scale).
2. **Map choice in the Race tab** (`Settings.map`, `Maps.LIST`). Circuits run
   in `race.tscn`, courses in `course_race.tscn`. Laps are greyed out on
   courses. The best **total time** is saved per course (same records as
   lap times, keyed by the map id).
3. **Skiing** (`SwanMotor.skiing`, set by the course on snow): gravity pulls
   the swan down the slope; accelerate = **tuck** (top speed 72 km/h, wider
   turns); brake = **open the wings** (snowplough); carving costs a little
   speed; jump still works. The model stands on two skis, no strides, and
   tucks. On the road the swan runs as usual (same 50 km/h rules).
4. **Fences and guard rails slide**, they don't daze: the swan is put back
   inside and loses the part of its speed going into them. A road full of
   curves would be frustrating with a 2.5 s daze at every touch.
5. **Animals** (`CourseMover`) move on a fixed pattern of the race clock, the
   same for every swan, and are solid like rocks: goats wander across the
   slope; cows and deer cross the road and wait at the side.
6. **Swiss Alps** (`AlpsCourse`, `AlpsScenery`), about 2:00 for a good racer:
   - **Ski slope, ~40 s**: 760 m down 120 m from a snowy top, 44 m wide, few
     curves. Pines (too tall to jump) and rocks (jumpable) in rows that never
     close the slope, and 9 wandering goats. Orange safety nets on the sides.
   - **Alpine road, ~1:20**: 1 km of two-lane mountain road (12 m) with 22
     stretches of curves left and right (28 to 60 m radius), gentle hills,
     guard rails, a dashed center line and pine forest on both sides. Five
     logs across one side or the middle (jump or go around) and five
     crossings of cows and deer.
   - Finish in a small village of chalets; the podium stands on the plaza.
   - Music: the island's tracks for now (TODO: the owner picks the Alps music).

## Consequences

- The island keeps working as it was; the new maps can't break it.
- Some logic exists twice (island and course versions of the rules, the bot,
  the race scene). If more circuits come, a shared base can be extracted then.
- Times are design targets from the motor numbers, not measured: play it,
  then adjust `SKI_*` in `SwanMotor`, the slope (`DROP`) or the road curves.
- The bots dodge what they see ahead; on the snow, small mistakes make them
  hit trees now and then, by design.
