class_name EgyptCircuit
extends CourseTrack
## Egypt (ADR 0030): a desert loop with laps, about 1:12 a lap, inspired by
## Egypt (not a copy of a real place). A packed-sand road with many sharp
## curves between sand dunes. The dunes are soft (CourseTrack.soft_edges): run
## up one and the swan gets slower and slower until it sinks and comes back
## on the road, like drowning on the island but in sand. Obstacles: whirling
## sand devils, big spinning spirals that wander across the road (solid, too
## tall to jump). Pyramids and sphinxes stand in the distance.
## Timing (SwanMotor): ~820 m a lap with sharp curves, about 1:12.

const LAP := 820.0
const HALF_WIDTH := 6.5
const OUTLINE_POINTS := 2400
## The layout, drawn by hand (x right, z down, m), then smoothed and scaled to
## the lap: hairpins and S-bends to both sides.
const WAYPOINTS := [Vector2(0, 0), Vector2(80, 0), Vector2(125, -38), Vector2(175, -58), Vector2(205, -15),
		Vector2(195, 35), Vector2(150, 62), Vector2(105, 40), Vector2(60, 85), Vector2(5, 82), Vector2(-45, 55),
		Vector2(-32, 18)]
const HILLS := [[2, 1.2, 0.3], [3, 0.7, 1.7]]
const SAND_DEVILS := 6


func _init() -> void:
	soft_edges = true
	sink_depth = 7.0
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
	var start := GermanyCircuit._straightest(raw, 60)
	var outline := PackedVector2Array()
	for n in raw.size():
		outline.append(raw[(start + n) % raw.size()])
	build_loop(outline)


func _height_at(d: float) -> float:
	var h := 0.0
	for hill: Array in HILLS:
		h += hill[1] * sin(TAU * hill[0] * d / LAP + hill[2])
	var from_start := absf(wrapf(d, -LAP * 0.5, LAP * 0.5))
	return h * smoothstep(30.0, 80.0, from_start) + 2.0


func _half_width(_d: float) -> Vector2:
	return Vector2(HALF_WIDTH, HALF_WIDTH)


func _terrain_at(_d: float) -> int:
	return Terrain.SAND


func stretch_name(_d: float) -> String:
	return "STRETCH_DESERT"


func build_scenery(parent: Node3D) -> void:
	EgyptScenery.build(parent, self)


func podium_spot() -> float:
	return 35.0


func turn_at(i: int) -> float:
	return tangent(i - 3).angle_to(tangent(i + 3)) / 6.0


func _place_features() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2560
	for n in SAND_DEVILS:
		var devil := SandDevil.new()
		devil.track = self
		devil.kind = "sand_devil"
		devil.pattern = CourseMover.Pattern.WANDER
		devil.home_distance = 70.0 + (length - 110.0) * (n + rng.randf_range(0.3, 0.7)) / SAND_DEVILS
		devil.home_lateral = 0.0
		devil.reach = HALF_WIDTH - 1.5
		devil.walk_speed = rng.randf_range(1.8, 2.8)
		devil.phase = rng.randf_range(0.0, 30.0)
		devil.radius = 1.0
		devil.height = 99.0
		movers.append(devil)
