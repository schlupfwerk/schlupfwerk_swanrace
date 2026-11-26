class_name SiderealCircuit
extends CourseTrack
## Sidereal Circuit (ADR 0024): a figure-8 track floating in space, with laps.
## It passes over itself: one crossing is a bridge 9 m up, the other runs
## under it. No fences and no water: off an edge, or on the ground over one
## of the holes in the deck, the swan falls into space and comes back a few
## seconds later (CourseRules). Asteroids on the deck: jump them.
## Timing (SwanMotor): ~1,350 m a lap of gentle curves, about 1:50 for a
## good racer (12-13 m/s with the bridge climb, holes and asteroids).

## The figure 8 (a lemniscate): half its length (x) and its height (z), m.
const SIZE := Vector2(255.0, 185.0)
const OUTLINE_POINTS := 1600
## The lap starts on the side of the right-hand loop, not in a curve.
const START_ANGLE := PI / 4.0
const HALF_WIDTH := 7.0
## The bridge over the crossing: height, flat top and ramps on each side.
const BRIDGE_HEIGHT := 9.0
const BRIDGE_TOP := 30.0
const BRIDGE_RAMP := 110.0
const HOLES := 7
const HOLE_LENGTH := 3.5
const ASTEROIDS := 16

## Distances of the two crossings: the bridge, and the way under it.
var bridge_at := 0.0
var under_at := 0.0
var _loop_length := 0.0


func _init() -> void:
	open_edges = true
	var outline := PackedVector2Array()
	var total := 0.0
	var previous := Vector2.ZERO
	for n in OUTLINE_POINTS:
		var t := START_ANGLE + TAU * n / OUTLINE_POINTS
		var p := Vector2(SIZE.x * cos(t), SIZE.y * sin(2.0 * t) * 0.5)
		if n > 0:
			total += previous.distance_to(p)
		# The crossings are where the 8 passes its middle (t = 90° and 270°).
		if bridge_at == 0.0 and t >= PI / 2.0:
			bridge_at = total
		if under_at == 0.0 and t >= 3.0 * PI / 2.0:
			under_at = total
		outline.append(p)
		previous = p
	_loop_length = total + previous.distance_to(outline[0])
	build_loop(outline)


func _height_at(d: float) -> float:
	var from_bridge := absf(wrapf(d - bridge_at, -_loop_length * 0.5, _loop_length * 0.5))
	var rise := 1.0 - smoothstep(BRIDGE_TOP * 0.5, BRIDGE_TOP * 0.5 + BRIDGE_RAMP, from_bridge)
	return BRIDGE_HEIGHT * rise


func _half_width(_d: float) -> Vector2:
	return Vector2(HALF_WIDTH, HALF_WIDTH)


func _terrain_at(_d: float) -> int:
	return Terrain.SPACE


func build_scenery(parent: Node3D) -> void:
	SiderealScenery.build(parent, self)


## The podium floats on the straight just past the start line.
func podium_spot() -> float:
	return 40.0


## True where nothing should be placed: the start, and right at the crossings.
func _keep_clear(d: float) -> bool:
	return absf(between(0.0, d)) < 45.0 or absf(between(under_at, d)) < 25.0 \
			or absf(between(bridge_at, d)) < 25.0


func _place_features() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4747
	var spots := HOLES + ASTEROIDS
	var holes_left := HOLES
	for n in spots:
		var d := length * (n + rng.randf_range(0.3, 0.7)) / spots
		if _keep_clear(d):
			continue
		# Every third spot is a hole, the rest asteroids.
		if n % 3 == 0 and holes_left > 0:
			holes_left -= 1
			var width := rng.randf_range(5.0, 8.0)
			# Against one edge (go around on the other side), or in the middle.
			var lateral := 0.0
			match rng.randi_range(0, 2):
				0:
					lateral = -HALF_WIDTH + width * 0.5
				1:
					lateral = HALF_WIDTH - width * 0.5
			add_hole(d, lateral, HOLE_LENGTH, width)
		else:
			add_obstacle(d, rng.randf_range(-HALF_WIDTH + 1.5, HALF_WIDTH - 1.5),
					rng.randf_range(0.7, 1.0), 0.6)
