class_name TokyoCircuit
extends CourseTrack
## Tokyo (ADR 0027): a short, irregular loop with laps through an old
## Japanese town, inspired by Japan (not a copy of any real place). Curves to
## the right and to the left, a stone-paved street between wooden houses with
## tiled roofs, cherry trees, lanterns, a pagoda, a tunnel of red torii gates
## and a snowy volcano far away. Obstacles: low wooden barrels (jump them or
## go around). Low fences at the edges (you slide along them).
## Timing (SwanMotor): ~950 m a lap, about 1:12 for a good racer (at most 1:20).

const LAP := 950.0
const HALF_WIDTH := 7.0
const OUTLINE_POINTS := 2400
## The layout, drawn by hand (x right, z down, m), then smoothed (Catmull-Rom)
## and scaled to the lap: an irregular loop with S-bends, curves both ways.
const WAYPOINTS := [Vector2(0, 0), Vector2(90, 0), Vector2(150, -30), Vector2(205, 5), Vector2(232, 65),
		Vector2(205, 118), Vector2(150, 108), Vector2(108, 140), Vector2(58, 168), Vector2(0, 150),
		Vector2(-48, 112), Vector2(-30, 74), Vector2(-62, 40), Vector2(-40, 4)]
const HILLS := [[2, 1.5, 0.5], [3, 0.8, 2.0]]
const BARRELS := 8
## The torii tunnel: from this far into the lap, this long.
const TORII_FROM := 0.55
const TORII_LENGTH := 70.0


func _init() -> void:
	# The fences at both edges are solid: running into them dazes.
	daze_sides = [-1.0, 1.0]
	var raw := PackedVector2Array()
	var count := WAYPOINTS.size()
	var per := OUTLINE_POINTS / count
	for k in count:
		var p0: Vector2 = WAYPOINTS[(k - 1 + count) % count]
		var p1: Vector2 = WAYPOINTS[k]
		var p2: Vector2 = WAYPOINTS[(k + 1) % count]
		var p3: Vector2 = WAYPOINTS[(k + 2) % count]
		for n in per:
			var t := float(n) / per
			raw.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	var perimeter := 0.0
	for n in raw.size():
		perimeter += raw[n].distance_to(raw[(n + 1) % raw.size()])
	for n in raw.size():
		raw[n] *= LAP / perimeter
	var start := GermanyCircuit._straightest(raw, 70)
	var outline := PackedVector2Array()
	for n in raw.size():
		outline.append(raw[(start + n) % raw.size()])
	build_loop(outline)


func _height_at(d: float) -> float:
	var h := 0.0
	for hill: Array in HILLS:
		h += hill[1] * sin(TAU * hill[0] * d / LAP + hill[2])
	var from_start := absf(wrapf(d, -LAP * 0.5, LAP * 0.5))
	return h * smoothstep(30.0, 90.0, from_start) + 3.0


func _half_width(_d: float) -> Vector2:
	return Vector2(HALF_WIDTH, HALF_WIDTH)


func _terrain_at(_d: float) -> int:
	return Terrain.ROAD


func stretch_name(d: float) -> String:
	var from := length * TORII_FROM
	if d > from and d < from + TORII_LENGTH:
		return "STRETCH_TORII"
	return "STRETCH_OLD_TOWN"


func build_scenery(parent: Node3D) -> void:
	TokyoScenery.build(parent, self)


func podium_spot() -> float:
	return 35.0


func turn_at(i: int) -> float:
	return tangent(i - 3).angle_to(tangent(i + 3)) / 6.0


func _place_features() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1868
	var placed := 0
	var tries := 0
	var torii_from := length * TORII_FROM
	while placed < BARRELS and tries < 200:
		tries += 1
		var d := 70.0 + (length - 110.0) * (placed + rng.randf_range(0.2, 0.8)) / BARRELS
		if absf(turn_at(index_at(d))) > 0.025:
			continue
		if d > torii_from - 10.0 and d < torii_from + TORII_LENGTH + 10.0:
			continue
		add_obstacle(d, rng.randf_range(-HALF_WIDTH + 1.5, HALF_WIDTH - 1.5), 0.6, 0.6)
		placed += 1
