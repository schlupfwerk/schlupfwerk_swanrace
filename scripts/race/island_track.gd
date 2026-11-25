class_name IslandTrack
extends RefCounted
## First circuit: laps around an island's beach, with the Atlantic forest on
## the left and the sea on the right. Bays make right-hand curves between the
## left-hand ones. Pure geometry and lap math, no visuals.
##
## Lap length comes from SwanMotor (13.9 m/s top speed, ~3 s to reach it).
## Target: a clean lap of ~1:10. With hills and banked curves that is 880 m:
## first lap from a standstill ~1:11.6, flying laps ~1:09 (~1:07 with turbo on
## the climbs). Hill heights scale with the length, so grades stay ~16%.
## Keep this in sync when the motor or the track changes.

const LAP_LENGTH := 880.0
const SAMPLES := 800
## Shape harmonics of the coastline (2nd, 3rd, 5th, 7th, 9th). Tight curves:
## about 35 m radius to the left and 18 m hairpins to the right in the bays.
const SHAPE := [0.3, 0.2, 0.12, 0.06, 0.02]
## Average half-widths of the sand from the racing line; they vary along the lap.
const FOREST_EDGE := -15.0
const WATER_LINE := 15.0
## In the water the swan is wet and slow; deeper than half its body, it drowns.
const WATER_SPEED_SCALE := 0.45
## How far the swan may turn away from the racing direction (never wrong way).
const MAX_WRONG_ANGLE := deg_to_rad(80.0)
const SEA_LEVEL := -0.6
## Water depth (m) at which the swan is half under water and drowns.
const DROWN_DEPTH := 1.15
const BUCKET := 8
## Hills along the lap (m): never below this, so the beach stays above the sea.
const BASE_HEIGHT := 0.6
## Banking: how much the sand tilts into a curve, and the most it ever tilts.
const BANK_PER_CURVATURE := 3.0
const MAX_BANK := 0.21
## Only the middle of the sand is banked; the edges level out.
const BANK_HALF_WIDTH := 10.0

## Shallow lake across the sand, with two bridges (lanes: water, bridge, water,
## bridge, water). Each bridge has a hole, at 30% and 70% of its length, so
## you jump it or drop into the water.
const LAKE_START := 0.46 # fraction of the lap
const LAKE_LENGTH := 42.0
const LAKE_DEPTH := 0.45
const LAKE_WATER := 0.3 # water above the lake floor
const BRIDGE_HEIGHT := 0.35
const BRIDGE_HOLES := [0.3, 0.7]
const HOLE_LENGTH := 3.2
const LAKE_SLOPE := 1.5
## Big logs lying across the sand: jump them (or go around near the edges).
const LOG_SPOTS := [0.12, 0.3, 0.64, 0.86]
const LOG_LENGTH := 9.0
const LOG_RADIUS := 0.38
## Speed pads on the sand.
const BOOST_SPOTS := [0.07, 0.24, 0.57, 0.79]
const BOOST_SIZE := Vector2(3.2, 4.5)

## Racing line in travel order, as (x, z).
var points := PackedVector2Array()
## Distance from the start line at each point.
var lengths := PackedFloat32Array()
var _forest := PackedFloat32Array()
var _water := PackedFloat32Array()
## Solid things on or near the sand (rocks, logs): {"p": Vector2, "r": radius,
## "h": height}. A swan in the air above "h" passes over it.
var obstacles: Array[Dictionary] = []
## Logs across the track: {"distance", "lateral"}. Speed pads: same keys.
var logs: Array[Dictionary] = []
var _podium_spot := -1.0
var boosters: Array[Dictionary] = []
## How far you can go to each side at point i before the ground folds over
## itself in a tight curve (positive = sea side).
var _room_right := PackedFloat32Array()
var _room_left := PackedFloat32Array()
## Height of the racing line and tilt of the sand (rise per meter to the right).
var _height := PackedFloat32Array()
var _bank := PackedFloat32Array()
var _buckets := {}


func _init() -> void:
	var raw := PackedVector2Array()
	for i in SAMPLES:
		# Decreasing angle: the island's center stays on the swan's left.
		var a := -TAU * i / SAMPLES
		var r := 1.0 + SHAPE[0] * sin(2.0 * a + 0.6) + SHAPE[1] * sin(3.0 * a + 2.1) \
				+ SHAPE[2] * sin(5.0 * a + 1.0) + SHAPE[3] * sin(7.0 * a + 0.3) \
				+ SHAPE[4] * sin(9.0 * a + 1.7)
		raw.append(Vector2(cos(a), sin(a)) * r)
	var raw_length := 0.0
	for i in SAMPLES:
		raw_length += raw[i].distance_to(raw[(i + 1) % SAMPLES])
	for i in SAMPLES:
		points.append(raw[i] * LAP_LENGTH / raw_length)
	_measure_room()
	_shape_ground()
	var total := 0.0
	for i in SAMPLES:
		lengths.append(total)
		total += points[i].distance_to(points[(i + 1) % SAMPLES])
		# The sand gets wider and narrower along the lap (about 20 to 38 m).
		var u := TAU * i / SAMPLES
		var forest := FOREST_EDGE - 4.0 * sin(3.0 * u + 1.0) - 1.5 * sin(7.0 * u)
		var water := WATER_LINE + 5.0 * sin(4.0 * u + 2.0) + 1.5 * sin(9.0 * u + 0.5)
		# Narrower sand inside the tightest curves.
		_forest.append(maxf(forest, -0.6 * _room_left[i]))
		_water.append(minf(water, 0.6 * _room_right[i]))
	# Logs and pads need the finished track (lengths, edges) to be placed.
	_place_features()


func tangent(i: int) -> Vector2:
	i = wrapi(i, 0, SAMPLES)
	return (points[(i + 1) % SAMPLES] - points[wrapi(i - 1, 0, SAMPLES)]).normalized()


## Unit vector to the right of the travel direction (towards the sea).
func right(i: int) -> Vector2:
	var t := tangent(i)
	return Vector2(-t.y, t.x)


## A point on the ground at `offset` meters to the right of the racing line.
func edge(i: int, offset: float) -> Vector2:
	i = wrapi(i, 0, SAMPLES)
	return points[i] + right(i) * offset


## Lateral offset of the forest edge (negative) at point i.
func forest_edge(i: int) -> float:
	return _forest[wrapi(i, 0, SAMPLES)]


## Lateral offset of the water line (positive) at point i.
func water_line(i: int) -> float:
	return _water[wrapi(i, 0, SAMPLES)]


## Height of the sand at a lateral offset (hills plus banking in curves).
func surface_height(i: int, lateral: float) -> float:
	i = wrapi(i, 0, SAMPLES)
	var tilted := _height[i] + clampf(lateral, -BANK_HALF_WIDTH, BANK_HALF_WIDTH) * _bank[i]
	return maxf(tilted, BASE_HEIGHT * 0.5)


## Height of the ground (sand, forest edge, lake floor or sea floor) at a
## lateral offset. Bridges are not included (see ground_height_at).
func ground_height(i: int, lateral: float) -> float:
	return _base_height(i, lateral) + _lake_depth(lengths[wrapi(i, 0, SAMPLES)], lateral)


func _base_height(i: int, lateral: float) -> float:
	var water := water_line(i)
	var forest := forest_edge(i)
	if lateral <= forest:
		return surface_height(i, forest)
	if lateral <= water:
		return surface_height(i, lateral)
	# From the top of the sand down a bank into the sea.
	var shore := surface_height(i, water)
	if lateral <= water + 5.0:
		return lerpf(shore, -0.5, (lateral - water) / 5.0)
	if lateral <= water + 10.0:
		return lerpf(-0.5, -1.6, (lateral - water - 5.0) / 5.0)
	return lerpf(-1.6, -3.4, clampf((lateral - water - 10.0) / 8.0, 0.0, 1.0))


func index_at(distance: float) -> int:
	distance = fposmod(distance, LAP_LENGTH)
	return clampi(lengths.bsearch(distance) - 1, 0, SAMPLES - 1)


## Heading (yaw) that faces the travel direction at point i.
func heading_at(i: int) -> float:
	var t := tangent(i)
	return atan2(-t.x, -t.y)


## Finds where `p` is: nearest index, distance along the lap and lateral offset.
## `hint` (last index, or -1) keeps the search local and cheap.
func locate(p: Vector2, hint: int) -> Dictionary:
	var best := 0
	var best_distance := INF
	var candidates: Array = range(SAMPLES) if hint < 0 else range(hint - 24, hint + 25)
	for k: int in candidates:
		var i := wrapi(k, 0, SAMPLES)
		var d := p.distance_squared_to(points[i])
		if d < best_distance:
			best_distance = d
			best = i
	var result := {}
	var nearest := INF
	for start: int in [wrapi(best - 1, 0, SAMPLES), best]:
		var a := points[start]
		var b := points[(start + 1) % SAMPLES]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var on_line := a + ab * t
		var d := p.distance_squared_to(on_line)
		if d < nearest:
			nearest = d
			result = {
				"index": best,
				"distance": fposmod(lengths[start] + ab.length() * t, LAP_LENGTH),
				"lateral": (p - on_line).dot(Vector2(-ab.y, ab.x).normalized()),
			}
	return result


## Registers something solid. Buckets by track index keep the checks cheap.
func add_obstacle(p: Vector2, radius: float, height: float) -> void:
	var index: int = locate(p, -1)["index"]
	obstacles.append({"p": p, "r": radius, "h": height})
	var bucket := index / BUCKET
	if not _buckets.has(bucket):
		_buckets[bucket] = []
	_buckets[bucket].append(obstacles.size() - 1)


## Obstacles close to track point i.
func obstacles_near(i: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var count := SAMPLES / BUCKET
	var bucket := wrapi(i, 0, SAMPLES) / BUCKET
	for b in [wrapi(bucket - 1, 0, count), bucket, wrapi(bucket + 1, 0, count)]:
		for n: int in _buckets.get(b, []):
			found.append(obstacles[n])
	return found


## Like edge(), but never past the point where a tight curve folds the ground.
func safe_edge(i: int, offset: float) -> Vector2:
	i = wrapi(i, 0, SAMPLES)
	return edge(i, clampf(offset, -0.9 * _room_left[i], 0.9 * _room_right[i]))


## True when `p` is out in open sea (not across a bay on another beach).
func is_open_sea(p: Vector2, margin := 12.0) -> bool:
	var info := locate(p, -1)
	return info["lateral"] > water_line(info["index"]) + margin


func _measure_room() -> void:
	var radius_right := PackedFloat32Array()
	var radius_left := PackedFloat32Array()
	for i in SAMPLES:
		var a := points[wrapi(i - 1, 0, SAMPLES)]
		var b := points[i]
		var c := points[(i + 1) % SAMPLES]
		var turn := (b - a).angle_to(c - b)
		var radius := (b - a).length() / maxf(absf(turn), 0.0001)
		# A right turn folds the sea side; a left turn folds the forest side.
		radius_right.append(radius if turn > 0.0 else INF)
		radius_left.append(radius if turn < 0.0 else INF)
	# Use the tightest curve nearby, so the limit is smooth along the lap.
	for i in SAMPLES:
		var right := INF
		var left := INF
		for k in range(-10, 11):
			right = minf(right, radius_right[wrapi(i + k, 0, SAMPLES)])
			left = minf(left, radius_left[wrapi(i + k, 0, SAMPLES)])
		_room_right.append(minf(right, 400.0))
		_room_left.append(minf(left, 400.0))


## Hills along the lap and banking that follows the curves.
func _shape_ground() -> void:
	var curvature := PackedFloat32Array()
	for i in SAMPLES:
		var a := points[wrapi(i - 1, 0, SAMPLES)]
		var b := points[i]
		var c := points[(i + 1) % SAMPLES]
		# Positive when turning right (the inside of the curve is on the right).
		curvature.append((b - a).angle_to(c - b) / maxf((b - a).length(), 0.01))
	for i in SAMPLES:
		var u := TAU * i / SAMPLES
		# Two rolling hills and a few smaller bumps, back to the start height.
		# Hill heights scale with the lap, so the grades stay the same (~16%).
		var hill := LAP_LENGTH / 1280.0
		_height.append(BASE_HEIGHT + hill * (5.0 * (1.0 - cos(3.0 * u)) + 2.6 * (1.0 - cos(7.0 * u + 1.0))))
		var smooth := 0.0
		for k in range(-12, 13):
			smooth += curvature[wrapi(i + k, 0, SAMPLES)]
		smooth /= 25.0
		# Tilt into the curve: the inside is lower.
		_bank.append(clampf(-smooth * BANK_PER_CURVATURE, -MAX_BANK, MAX_BANK))


## Ground height at a point given by its distance along the lap, blending the
## two nearest samples, so climbs are smooth slopes and not little steps.
func ground_height_at(distance: float, lateral: float) -> float:
	var i := index_at(distance)
	var next := (i + 1) % SAMPLES
	var span := lengths[next] - lengths[i] if next > 0 else LAP_LENGTH - lengths[i]
	var t := clampf((fposmod(distance, LAP_LENGTH) - lengths[i]) / maxf(span, 0.001), 0.0, 1.0)
	var ground := lerpf(_base_height(i, lateral), _base_height(next, lateral), t)
	return ground + _lake_offset(distance, lateral)


## True when the point is in the lake water (not on a bridge): wet and slow.
func in_lake_water(distance: float, lateral: float) -> bool:
	return _lake_offset(distance, lateral) < -LAKE_WATER


## Height of the lake water surface at a point (only meaningful in the lake).
func lake_water_height(distance: float, lateral: float) -> float:
	var i := index_at(distance)
	return _base_height(i, lateral) - LAKE_DEPTH + LAKE_WATER


## Which lake lane a point is in (0..4: water, bridge, water, bridge, water),
## or -1 outside the lake. `along` gets the distance into the lake.
func lake_lane(distance: float, lateral: float) -> int:
	var along := fposmod(distance - LAKE_START * LAP_LENGTH, LAP_LENGTH)
	if along > LAKE_LENGTH + LAKE_SLOPE and along < LAP_LENGTH - LAKE_SLOPE:
		return -1
	var i := index_at(distance)
	var left := forest_edge(i) + 1.0
	var right := water_line(i) - 1.0
	if lateral < left or lateral > right:
		return -1
	return clampi(int((lateral - left) / (right - left) * 5.0), 0, 4)


## Distance into the lake (negative before it).
func lake_along(distance: float) -> float:
	var along := fposmod(distance - LAKE_START * LAP_LENGTH, LAP_LENGTH)
	return along - LAP_LENGTH if along > LAP_LENGTH * 0.5 else along


## The lake floor below the sand (0 outside the lake, sloping in at both ends).
func _lake_depth(distance: float, lateral: float) -> float:
	if lake_lane(distance, lateral) < 0:
		return 0.0
	var along := lake_along(distance)
	var edge := minf(along + LAKE_SLOPE, LAKE_LENGTH + LAKE_SLOPE - along) / LAKE_SLOPE
	return -LAKE_DEPTH * clampf(edge, 0.0, 1.0)


## Lake floor, or the bridge deck (with its hole) in the bridge lanes.
func _lake_offset(distance: float, lateral: float) -> float:
	var lane := lake_lane(distance, lateral)
	var depth := _lake_depth(distance, lateral)
	if lane != 1 and lane != 3:
		return depth
	var along := lake_along(distance)
	var hole: float = BRIDGE_HOLES[0 if lane == 1 else 1] * LAKE_LENGTH
	if absf(along - hole) < HOLE_LENGTH * 0.5:
		return depth
	# The deck ramps up from the sand at both ends.
	var ramp := clampf(minf(along + LAKE_SLOPE, LAKE_LENGTH + LAKE_SLOPE - along) / (LAKE_SLOPE * 2.0),
			0.0, 1.0)
	return BRIDGE_HEIGHT * ramp


func _place_features() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for spot: float in LOG_SPOTS:
		var distance := spot * LAP_LENGTH
		var i := index_at(distance)
		var lateral := rng.randf_range(-3.0, 3.0)
		logs.append({"distance": distance, "lateral": lateral})
		# Solid, but low: a jump clears it.
		var across := right(i)
		for k in range(-7, 8):
			var p := edge(i, lateral) + across * (k * LOG_LENGTH / 14.0)
			add_obstacle(p, LOG_RADIUS + 0.05, LOG_RADIUS * 2.0 - 0.2)
	for spot: float in BOOST_SPOTS:
		boosters.append({"distance": spot * LAP_LENGTH, "lateral": rng.randf_range(-5.0, 5.0)})


## The speed pad under a point, if any (true when on it).
func on_booster(distance: float, lateral: float) -> bool:
	for pad in boosters:
		var along := fposmod(distance - pad.distance + LAP_LENGTH * 0.5, LAP_LENGTH) - LAP_LENGTH * 0.5
		if absf(along) < BOOST_SIZE.y * 0.5 and absf(lateral - pad.lateral) < BOOST_SIZE.x * 0.5:
			return true
	return false


## True when a log or a bridge hole is right ahead, in this lane, between
## `from` and `to` meters ahead (for the obstacle alert and the bots).
func obstacle_ahead(distance: float, lateral: float, from := 6.0, to := 22.0) -> bool:
	for log in logs:
		var gap := fposmod(log.distance - distance, LAP_LENGTH)
		if gap > from and gap < to and absf(lateral - log.lateral) < LOG_LENGTH * 0.5 + 0.8:
			return true
	var lane := lake_lane(distance, lateral)
	if lane == 1 or lane == 3:
		var hole: float = BRIDGE_HOLES[0 if lane == 1 else 1] * LAKE_LENGTH
		var gap := hole - HOLE_LENGTH * 0.5 - lake_along(distance)
		if gap > from * 0.5 and gap < to:
			return true
	return false


## The log right ahead in this lane (within `to` meters), or an empty dict.
func log_ahead(distance: float, lateral: float, to: float) -> Dictionary:
	for log in logs:
		var gap := fposmod(log.distance - distance, LAP_LENGTH)
		if gap < to and absf(lateral - log.lateral) < LOG_LENGTH * 0.5 + 0.8:
			return log
	return {}


## Where the podium goes after the race: the straightest, flattest stretch of
## wide sand (about 28 m), away from logs, the lake, speed pads and the start.
## Returns the distance where the row of blocks begins.
func podium_spot() -> float:
	if _podium_spot >= 0.0:
		return _podium_spot
	var best := INF
	var keep_clear: Array[float] = [0.0]
	for log in logs:
		keep_clear.append(log.distance)
	for pad in boosters:
		keep_clear.append(pad.distance)
	var d := 20.0
	while d < LAP_LENGTH - 40.0:
		var score := 0.0
		var low := INF
		var high := -INF
		var first := heading_at(index_at(d - 4.0))
		var blocked := false
		var step := -4.0
		while step <= 24.0:
			var at := d + step
			var i := index_at(at)
			var height := ground_height_at(at, 0.0)
			low = minf(low, height)
			high = maxf(high, height)
			score += absf(wrapf(heading_at(i) - first, -PI, PI)) * 4.0
			if water_line(i) - forest_edge(i) < 22.0 or lake_along(at) > -12.0 \
					and lake_along(at) < LAKE_LENGTH + 4.0:
				blocked = true
			step += 2.0
		for spot in keep_clear:
			if absf(wrapf(spot - (d + 10.0), -LAP_LENGTH / 2.0, LAP_LENGTH / 2.0)) < 22.0:
				blocked = true
		score += (high - low) * 3.0
		if not blocked and score < best:
			best = score
			_podium_spot = d
		d += 4.0
	if _podium_spot < 0.0:
		_podium_spot = LAP_LENGTH * 0.4
	return _podium_spot
