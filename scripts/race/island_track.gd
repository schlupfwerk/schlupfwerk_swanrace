class_name IslandTrack
extends RefCounted
## First circuit: laps around an island's beach, with the Atlantic forest on
## the left and the sea on the right. Bays make right-hand curves between the
## left-hand ones. Pure geometry and lap math, no visuals.
##
## Lap length comes from SwanMotor (13.9 m/s top speed, ~3 s to reach it).
## The first version (1000 m) gave ~1:15 for a clean lap; this one is 60%
## longer, so a clean lap is ~1:57 and a struggling one ~3:10. Keep this in
## sync when the motor changes.

const LAP_LENGTH := 1600.0
const SAMPLES := 800
## Shape harmonics of the coastline (2nd, 3rd, 5th, 7th).
const SHAPE := [0.27, 0.16, 0.09, 0.045]
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

## Racing line in travel order, as (x, z).
var points := PackedVector2Array()
## Distance from the start line at each point.
var lengths := PackedFloat32Array()
var _forest := PackedFloat32Array()
var _water := PackedFloat32Array()
## Solid things on or near the sand (rocks, logs): {"p": Vector2, "r": radius,
## "h": height}. A swan in the air above "h" passes over it.
var obstacles: Array[Dictionary] = []
var _buckets := {}


func _init() -> void:
	var raw := PackedVector2Array()
	for i in SAMPLES:
		# Decreasing angle: the island's center stays on the swan's left.
		var a := -TAU * i / SAMPLES
		var r := 1.0 + SHAPE[0] * sin(2.0 * a + 0.6) + SHAPE[1] * sin(3.0 * a + 2.1) \
				+ SHAPE[2] * sin(5.0 * a + 1.0) + SHAPE[3] * sin(7.0 * a + 0.3)
		raw.append(Vector2(cos(a), sin(a)) * r)
	var raw_length := 0.0
	for i in SAMPLES:
		raw_length += raw[i].distance_to(raw[(i + 1) % SAMPLES])
	for i in SAMPLES:
		points.append(raw[i] * LAP_LENGTH / raw_length)
	var total := 0.0
	for i in SAMPLES:
		lengths.append(total)
		total += points[i].distance_to(points[(i + 1) % SAMPLES])
		# The sand gets wider and narrower along the lap (about 20 to 38 m).
		var u := TAU * i / SAMPLES
		_forest.append(FOREST_EDGE - 4.0 * sin(3.0 * u + 1.0) - 1.5 * sin(7.0 * u))
		_water.append(WATER_LINE + 5.0 * sin(4.0 * u + 2.0) + 1.5 * sin(9.0 * u + 0.5))


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


## Height of the ground (sand or sea floor) at a lateral offset.
func ground_height(i: int, lateral: float) -> float:
	var water := water_line(i)
	if lateral <= water:
		return 0.0
	# Steep: the sea floor drops fast, so the swan sinks quickly.
	if lateral <= water + 3.0:
		return lerpf(0.0, -0.5, (lateral - water) / 3.0)
	if lateral <= water + 8.0:
		return lerpf(-0.5, -1.6, (lateral - water - 3.0) / 5.0)
	return lerpf(-1.6, -3.4, clampf((lateral - water - 8.0) / 8.0, 0.0, 1.0))


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
