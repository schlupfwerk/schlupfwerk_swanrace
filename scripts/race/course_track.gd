class_name CourseTrack
extends RefCounted
## A point-to-point course: one start, one finish, no laps (ADR 0022). The
## center line is built by walking SPACING meters at a time and turning by the
## curvature a subclass gives for each distance, so lengths are exact and the
## curves are smooth. Subclasses also say how high the ground is, how wide
## the course is and which terrain each stretch has. Geometry, positions and
## obstacles only: no visuals (each course has its own scenery script).

enum Terrain { SNOW, ROAD }

## Distance between samples of the center line (m).
const SPACING := 1.0
## Curvature is averaged over this many samples each way, so a curve eases in.
const CURVE_BLEND := 8
const BUCKET := 8
## How far a swan may turn away from the race direction (never the wrong way).
const MAX_WRONG_ANGLE := deg_to_rad(80.0)
## How far the search for a swan's place looks around the last known sample.
const SEARCH := 30

## Center line in travel order, as (x, z), and the distance at each sample.
var points := PackedVector2Array()
var lengths := PackedFloat32Array()
## Whole length of the center line (m).
var length := 0.0
## The start line and the finish line, as distances along the course.
var start_distance := 40.0
var finish_distance := 0.0
## Solid things: {"p": Vector2, "r": radius, "h": height, "d": distance, "l": lateral}.
## A swan in the air above "h" passes over it.
var obstacles: Array[Dictionary] = []
## Animals that walk around (CourseMover), checked every tick.
var movers: Array[CourseMover] = []
## Logs across the course: {"distance", "lateral", "length"}. Jump them or go around.
var logs: Array[Dictionary] = []

var _height := PackedFloat32Array()
var _left := PackedFloat32Array()
var _right := PackedFloat32Array()
var _terrain := PackedInt32Array()
var _buckets := {}


## Builds the center line from the subclass's description. Call it at the end
## of the subclass's _init, once its constants are set.
func build() -> void:
	var count := int(total_length() / SPACING) + 1
	var raw := PackedFloat32Array()
	for n in count:
		raw.append(_curvature(n * SPACING))
	var heading := 0.0
	var p := Vector2.ZERO
	for n in count:
		var sum := 0.0
		var used := 0
		for k in range(n - CURVE_BLEND, n + CURVE_BLEND + 1):
			if k >= 0 and k < count:
				sum += raw[k]
				used += 1
		var d := n * SPACING
		points.append(p)
		lengths.append(d)
		_height.append(_height_at(d))
		var half := _half_width(d)
		_left.append(-half.x)
		_right.append(half.y)
		_terrain.append(_terrain_at(d))
		# Positive curvature turns right, like steering right (SwanMotor).
		heading -= sum / used * SPACING
		p += Vector2(-sin(heading), -cos(heading)) * SPACING
	length = lengths[count - 1]
	_place_features()


# --- What a course describes (override these) ------------------------------------

## Length of the center line (m), past the finish line to leave room for the podium.
func total_length() -> float:
	return 1000.0


## Turn at a distance (1 / radius in meters; positive = to the right).
func _curvature(_d: float) -> float:
	return 0.0


## Height of the center line at a distance.
func _height_at(_d: float) -> float:
	return 0.0


## Room to the left (x) and to the right (y) of the center line (m).
func _half_width(_d: float) -> Vector2:
	return Vector2(6.0, 6.0)


func _terrain_at(_d: float) -> int:
	return Terrain.ROAD


## Obstacles, logs and animals, once the center line exists.
func _place_features() -> void:
	pass


## Builds the course's scenery (and the animals' bodies) under `parent`.
func build_scenery(_parent: Node3D) -> void:
	pass


## Name of the stretch at a distance (for the HUD), a translation key.
func stretch_name(_d: float) -> String:
	return ""


# --- Geometry -----------------------------------------------------------------------

func sample_count() -> int:
	return points.size()


func tangent(i: int) -> Vector2:
	var last := points.size() - 1
	var a := points[clampi(i - 1, 0, last)]
	var b := points[clampi(i + 1, 0, last)]
	return (b - a).normalized()


## Unit vector to the right of the travel direction.
func right(i: int) -> Vector2:
	var t := tangent(i)
	return Vector2(-t.y, t.x)


## A point on the ground at `offset` meters to the right of the center line.
func edge(i: int, offset: float) -> Vector2:
	i = clampi(i, 0, points.size() - 1)
	return points[i] + right(i) * offset


## Lateral offset of the left edge (negative) and of the right edge (positive).
func left_edge(i: int) -> float:
	return _left[clampi(i, 0, points.size() - 1)]


func right_edge(i: int) -> float:
	return _right[clampi(i, 0, points.size() - 1)]


func terrain(distance: float) -> int:
	return _terrain[index_at(distance)]


func index_at(distance: float) -> int:
	return clampi(int(distance / SPACING), 0, points.size() - 1)


## Heading (yaw) that faces the travel direction at sample i.
func heading_at(i: int) -> float:
	var t := tangent(i)
	return atan2(-t.x, -t.y)


## Height of the ground at a distance along the course and a lateral offset,
## blending the two nearest samples (smooth slopes, no steps). Outside the
## edges the ground rises a little (snow banks, road embankments).
func ground_height_at(distance: float, lateral: float) -> float:
	var i := index_at(distance)
	var next := mini(i + 1, points.size() - 1)
	var t := clampf((distance - lengths[i]) / SPACING, 0.0, 1.0)
	var center := lerpf(_height[i], _height[next], t)
	var outside := maxf(lateral - _right[i], _left[i] - lateral)
	return center + maxf(outside, 0.0) * 0.25


## Finds where `p` is: nearest sample, distance along the course and lateral
## offset. `hint` (last sample, or -1) keeps the search local and cheap.
func locate(p: Vector2, hint: int) -> Dictionary:
	var last := points.size() - 1
	var from := 0 if hint < 0 else maxi(hint - SEARCH, 0)
	var to := last if hint < 0 else mini(hint + SEARCH, last)
	var best := from
	var best_distance := INF
	for i in range(from, to + 1):
		var d := p.distance_squared_to(points[i])
		if d < best_distance:
			best_distance = d
			best = i
	var result := {}
	var nearest := INF
	for start: int in [maxi(best - 1, 0), mini(best, last - 1)]:
		var a := points[start]
		var b := points[start + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var on_line := a + ab * t
		var d := p.distance_squared_to(on_line)
		if d < nearest:
			nearest = d
			result = {
				"index": best,
				"distance": lengths[start] + ab.length() * t,
				"lateral": (p - on_line).dot(Vector2(-ab.y, ab.x).normalized()),
			}
	return result


# --- Obstacles ----------------------------------------------------------------------

## Registers something solid at a place on the course, `height` meters tall
## (above the ground: swans keep their height above the ground, SwanMotor).
func add_obstacle(distance: float, lateral: float, radius: float, height: float) -> void:
	var i := index_at(distance)
	obstacles.append({"p": edge(i, lateral), "r": radius, "h": height, "d": distance,
			"l": lateral})
	var bucket := i / BUCKET
	if not _buckets.has(bucket):
		_buckets[bucket] = []
	_buckets[bucket].append(obstacles.size() - 1)


## Static obstacles close to sample i.
func obstacles_near(i: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var bucket := clampi(i, 0, points.size() - 1) / BUCKET
	for b in [bucket - 1, bucket, bucket + 1]:
		for n: int in _buckets.get(b, []):
			found.append(obstacles[n])
	return found


## Animals within `reach` meters (along the course) of a distance.
func movers_near(distance: float, reach := 8.0) -> Array[CourseMover]:
	var found: Array[CourseMover] = []
	for mover in movers:
		if absf(mover.distance - distance) < reach:
			found.append(mover)
	return found


## A log lying across the course: solid but low, so a jump clears it.
func add_log(distance: float, lateral: float, log_length: float) -> void:
	logs.append({"distance": distance, "lateral": lateral, "length": log_length})
	var i := index_at(distance)
	var steps := int(log_length / 0.6)
	for k in range(-steps / 2, steps / 2 + 1):
		add_obstacle(distance, lateral + k * log_length / steps, 0.43, 0.56)


## True when a log is right ahead in this lane, between `from` and `to` meters
## ahead (for the "Jump!" alert and the bots).
func obstacle_ahead(distance: float, lateral: float, from := 6.0, to := 22.0) -> bool:
	return not log_ahead(distance, lateral, to, from).is_empty()


## The log right ahead in this lane (between `from` and `to` meters), or {}.
func log_ahead(distance: float, lateral: float, to: float, from := 0.0) -> Dictionary:
	for log in logs:
		var gap: float = log.distance - distance
		if gap > from and gap < to and absf(lateral - log.lateral) < log.length * 0.5 + 0.8:
			return log
	return {}


## The nearest thing in the way (rock, tree or animal) between `from` and `to`
## meters ahead, within `lane` meters of this lateral offset: {"d", "l", "r"},
## or {} when the way is clear. Logs are left out (they are jumped).
func blocker_ahead(distance: float, lateral: float, to: float, from := 1.0, lane := 1.4) -> Dictionary:
	var best := {}
	var best_gap := INF
	var first := index_at(distance + from) / BUCKET
	var last := index_at(distance + to) / BUCKET
	for b in range(first, last + 1):
		for n: int in _buckets.get(b, []):
			var o := obstacles[n]
			if o.h < 0.7:
				continue
			var gap: float = o.d - distance
			if gap > from and gap < to and gap < best_gap and absf(o.l - lateral) < o.r + lane:
				best = {"d": o.d, "l": o.l, "r": o.r}
				best_gap = gap
	for mover in movers:
		var gap := mover.distance - distance
		if gap > from and gap < to and gap < best_gap \
				and absf(mover.lateral - lateral) < mover.radius + lane:
			best = {"d": mover.distance, "l": mover.lateral, "r": mover.radius}
			best_gap = gap
	return best


## Where the podium goes: on the flat stretch past the finish line.
## Returns the distance where the row of blocks begins.
func podium_spot() -> float:
	return minf(finish_distance + 16.0, length - 30.0)
