class_name IslandTrack
extends RefCounted
## First circuit: one lap around an island's beach, with the Atlantic forest on
## the left and the sea on the right. Pure geometry and lap math, no visuals.
##
## Lap length comes from SwanMotor (13.9 m/s top speed, ~3 s to reach it):
## a clean lap at top speed is 21 m + (75 s - 3 s) * 13.9 m/s ~= 1000 m, so a
## good player laps in about 1:15 and a struggling one (zig-zags, brakes,
## off the sand) in about 2:00. Keep this in sync when the motor changes.

const LAP_LENGTH := 1000.0
const SAMPLES := 512
## Lateral offsets from the racing line (positive = towards the sea).
const FOREST_EDGE := -16.0
const WATER_LINE := 16.0
## Speed limit when outside the sand (in the forest or in the water).
const OFF_TRACK_SPEED_SCALE := 0.45

## Racing line in travel order, as (x, z).
var points := PackedVector2Array()
## Distance from the start line at each point.
var lengths := PackedFloat32Array()


func _init() -> void:
	var raw := PackedVector2Array()
	for i in SAMPLES:
		# Decreasing angle: the island's center stays on the swan's left.
		var a := -TAU * i / SAMPLES
		var r := 1.0 + 0.12 * sin(2.0 * a + 0.6) + 0.07 * sin(3.0 * a + 2.1) + 0.03 * sin(5.0 * a)
		raw.append(Vector2(cos(a), sin(a)) * r)
	var raw_length := 0.0
	for i in SAMPLES:
		raw_length += raw[i].distance_to(raw[(i + 1) % SAMPLES])
	var total := 0.0
	for i in SAMPLES:
		points.append(raw[i] * LAP_LENGTH / raw_length)
	for i in SAMPLES:
		lengths.append(total)
		total += points[i].distance_to(points[(i + 1) % SAMPLES])


func tangent(i: int) -> Vector2:
	return (points[(i + 1) % SAMPLES] - points[wrapi(i - 1, 0, SAMPLES)]).normalized()


## Unit vector to the right of the travel direction (towards the sea).
func right(i: int) -> Vector2:
	var t := tangent(i)
	return Vector2(-t.y, t.x)


## A point on the ground at `offset` meters to the right of the racing line.
func edge(i: int, offset: float) -> Vector2:
	return points[wrapi(i, 0, SAMPLES)] + right(wrapi(i, 0, SAMPLES)) * offset


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
