class_name ParisCircuit
extends CourseTrack
## Paris (ADR 0032): an easy loop with laps, run clockwise through the city,
## inspired by Paris (not a copy of a real street). A wide cobblestone street
## with gentle curves and guard rails on both sides (solid: running into them
## dazes). On the right, inside the loop, a park with the Eiffel Tower in the
## middle; on the left, rows of typical Parisian buildings with cafés. No
## obstacles: an easy race. About 1:00 a lap.

const LAP := 800.0
const HALF_WIDTH := 8.0
const OUTLINE_POINTS := 2000
## The layout (x right, z down, m), smoothed and scaled: wide, gentle curves.
const WAYPOINTS := [Vector2(0, 0), Vector2(120, -12), Vector2(215, 0), Vector2(265, 60), Vector2(235, 130),
		Vector2(145, 152), Vector2(45, 140), Vector2(-25, 100), Vector2(-40, 40)]
const GROUND := 1.0


func _init() -> void:
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
	var start := GermanyCircuit._straightest(raw, 60)
	var outline := PackedVector2Array()
	for n in raw.size():
		outline.append(raw[(start + n) % raw.size()])
	build_loop(outline)


func _height_at(_d: float) -> float:
	return GROUND


func _half_width(_d: float) -> Vector2:
	return Vector2(HALF_WIDTH, HALF_WIDTH)


func _terrain_at(_d: float) -> int:
	return Terrain.ROAD


func stretch_name(_d: float) -> String:
	return "STRETCH_PARIS_STREETS"


func build_scenery(parent: Node3D) -> void:
	ParisScenery.build(parent, self)


func podium_spot() -> float:
	return 35.0
