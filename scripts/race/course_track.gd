class_name CourseTrack
extends RefCounted
## A course for the maps after the island (ADR 0022): usually point to point
## (one start, one finish, no laps). The center line is built by walking
## SPACING meters at a time and turning by the curvature a subclass gives for
## each distance, so lengths are exact and the curves are smooth. Subclasses
## also say how high the ground is, how wide the course is and which terrain
## each stretch has. Geometry, positions and obstacles only: no visuals (each
## course has its own scenery script).
##
## A course can also be a closed loop with laps (`looped`, ADR 0024), built
## from a closed outline with build_loop(); then distances wrap around and the
## start line is at distance 0. Loops may pass over themselves (bridges): every
## search stays near the swan's last known sample, so the other level is never
## mixed up with this one.

enum Terrain { SNOW, ROAD, SAND, SPACE }

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
## Small puddles: {"distance", "lateral", "radius"}. Jump them, or splash
## through and lose speed (CourseRules).
var puddles: Array[Dictionary] = []
## Holes in the deck (space): {"distance", "lateral", "length", "width"}. Jump
## them, or fall (CourseRules).
var holes: Array[Dictionary] = []
## A closed loop with laps (start line at distance 0) instead of a run.
var looped := false
## No fences: running off an edge, the swan falls (CourseRules).
var open_edges := false
## Broken stretches of an otherwise fenced edge (the Great Wall's parapet):
## {"from", "to", "side"} (side -1 = left, 1 = right). Off the edge there,
## the swan falls (CourseRules).
var breaks: Array[Dictionary] = []
## Sides (-1 left, 1 right) whose edge is a solid wall, curb or fence: running
## into it dazes the swan, like the forest edge on the island (CourseRules).
var daze_sides: Array[float] = []

## Distance between samples: SPACING, or a little more or less on a loop so
## that a whole number of samples closes it.
var _step := SPACING

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


## Builds a closed loop from an outline (any spacing, in travel order; the
## last point joins the first), resampled every ~SPACING meters. Heights,
## widths and terrain come from the subclass as for a run. Call it at the end
## of the subclass's _init.
func build_loop(outline: PackedVector2Array) -> void:
	looped = true
	var count := outline.size()
	var along := PackedFloat32Array()
	var total := 0.0
	for n in count:
		along.append(total)
		total += outline[n].distance_to(outline[(n + 1) % count])
	var samples := maxi(int(round(total / SPACING)), 8)
	_step = total / samples
	var k := 0
	for n in samples:
		var d := n * _step
		while k + 1 < count and along[k + 1] <= d:
			k += 1
		var next := (k + 1) % count
		var span := (along[k + 1] if k + 1 < count else total) - along[k]
		var t := (d - along[k]) / maxf(span, 0.0001)
		points.append(outline[k].lerp(outline[next], t))
		lengths.append(d)
		_height.append(_height_at(d))
		var half := _half_width(d)
		_left.append(-half.x)
		_right.append(half.y)
		_terrain.append(_terrain_at(d))
	length = total
	start_distance = 0.0
	finish_distance = 0.0
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


## Top of the speedometer scale (km/h): higher where swans ski.
func max_kmh() -> float:
	return 60.0


## Name of the stretch at a distance (for the HUD), a translation key.
func stretch_name(_d: float) -> String:
	return ""


# --- Geometry -----------------------------------------------------------------------

func sample_count() -> int:
	return points.size()


## A valid sample index: wraps around on a loop, stops at the ends of a run.
func wrap_index(i: int) -> int:
	return wrapi(i, 0, points.size()) if looped else clampi(i, 0, points.size() - 1)


## Meters from `from` to `to` along the course (on a loop, always ahead: 0..length).
func ahead(from: float, to: float) -> float:
	return fposmod(to - from, length) if looped else to - from


## Like ahead(), but on a loop the shorter way (negative when behind).
func between(from: float, to: float) -> float:
	return wrapf(to - from, -length * 0.5, length * 0.5) if looped else to - from


func tangent(i: int) -> Vector2:
	var a := points[wrap_index(i - 1)]
	var b := points[wrap_index(i + 1)]
	return (b - a).normalized()


## Unit vector to the right of the travel direction.
func right(i: int) -> Vector2:
	var t := tangent(i)
	return Vector2(-t.y, t.x)


## A point on the ground at `offset` meters to the right of the center line.
func edge(i: int, offset: float) -> Vector2:
	i = wrap_index(i)
	return points[i] + right(i) * offset


## Lateral offset of the left edge (negative) and of the right edge (positive).
func left_edge(i: int) -> float:
	return _left[wrap_index(i)]


func right_edge(i: int) -> float:
	return _right[wrap_index(i)]


func terrain(distance: float) -> int:
	return _terrain[index_at(distance)]


func index_at(distance: float) -> int:
	if looped:
		return wrapi(int(fposmod(distance, length) / _step), 0, points.size())
	return clampi(int(distance / _step), 0, points.size() - 1)


## Heading (yaw) that faces the travel direction at sample i.
func heading_at(i: int) -> float:
	var t := tangent(i)
	return atan2(-t.x, -t.y)


## Height of the ground at a distance along the course and a lateral offset,
## blending the two nearest samples (smooth slopes, no steps). Outside the
## edges the ground rises a little (snow banks, road embankments).
func ground_height_at(distance: float, lateral: float) -> float:
	var i := index_at(distance)
	var next := wrap_index(i + 1)
	if looped:
		distance = fposmod(distance, length)
	var t := clampf((distance - lengths[i]) / _step, 0.0, 1.0)
	var center := lerpf(_height[i], _height[next], t)
	var outside := maxf(lateral - _right[i], _left[i] - lateral)
	return center + maxf(outside, 0.0) * 0.25


## Finds where `p` is: nearest sample, distance along the course and lateral
## offset. `hint` (last sample, or -1) keeps the search local and cheap.
func locate(p: Vector2, hint: int) -> Dictionary:
	var last := points.size() - 1
	var from := 0
	var to := last
	if hint >= 0:
		from = hint - SEARCH if looped else maxi(hint - SEARCH, 0)
		to = hint + SEARCH if looped else mini(hint + SEARCH, last)
	var best := wrap_index(from)
	var best_distance := INF
	for k in range(from, to + 1):
		var i := wrap_index(k)
		var d := p.distance_squared_to(points[i])
		if d < best_distance:
			best_distance = d
			best = i
	var result := {}
	var nearest := INF
	var starts: Array[int] = []
	if looped:
		starts.append(wrap_index(best - 1))
		starts.append(best)
	else:
		starts.append(maxi(best - 1, 0))
		starts.append(mini(best, last - 1))
	for start in starts:
		var a := points[start]
		var b := points[wrap_index(start + 1)]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
		var on_line := a + ab * t
		var d := p.distance_squared_to(on_line)
		if d < nearest:
			nearest = d
			var at := lengths[start] + ab.length() * t
			result = {
				"index": best,
				"distance": fposmod(at, length) if looped else at,
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
	var bucket := wrap_index(i) / BUCKET
	for b in [bucket - 1, bucket, bucket + 1]:
		for n: int in _buckets.get(_wrap_bucket(b), []):
			found.append(obstacles[n])
	return found


func _wrap_bucket(b: int) -> int:
	if not looped:
		return b
	return wrapi(b, 0, (points.size() + BUCKET - 1) / BUCKET)


## Animals within `reach` meters (along the course) of a distance.
func movers_near(distance: float, reach := 8.0) -> Array[CourseMover]:
	var found: Array[CourseMover] = []
	for mover in movers:
		if absf(between(distance, mover.distance)) < reach:
			found.append(mover)
	return found


## A log lying across the course: solid but low, so a jump clears it.
func add_log(distance: float, lateral: float, log_length: float) -> void:
	logs.append({"distance": distance, "lateral": lateral, "length": log_length})
	var i := index_at(distance)
	var steps := int(log_length / 0.6)
	for k in range(-steps / 2, steps / 2 + 1):
		add_obstacle(distance, lateral + k * log_length / steps, 0.43, 0.56)
		obstacles[-1]["log"] = true


## True when a log or a puddle is right ahead in this lane, between `from`
## and `to` meters ahead (for the "Jump!" alert and the bots).
func obstacle_ahead(distance: float, lateral: float, from := 6.0, to := 22.0) -> bool:
	if not log_ahead(distance, lateral, to, from).is_empty():
		return true
	for puddle in puddles:
		var gap: float = ahead(distance, puddle.distance - puddle.radius)
		if gap > from * 0.5 and gap < to and absf(lateral - puddle.lateral) < puddle.radius + 0.5:
			return true
	for hole in holes:
		var gap: float = ahead(distance, hole.distance - hole.length * 0.5)
		if gap > from * 0.5 and gap < to and absf(lateral - hole.lateral) < hole.width * 0.5 + 0.5:
			return true
	return false


## A broken stretch of the fence on one side (-1 left, 1 right).
func add_break(from: float, to: float, side: float) -> void:
	breaks.append({"from": from, "to": to, "side": side})


## True where a swan can fall off this side of the course: everywhere with
## open edges, or along a broken stretch.
func edge_open(distance: float, side: float) -> bool:
	if open_edges:
		return true
	for gap in breaks:
		if gap.side == side and between(gap.from, distance) >= 0.0 and between(distance, gap.to) >= 0.0:
			return true
	return false


## What the HUD says when a swan falls (a translation key).
func fall_message() -> String:
	return "CAREFUL_SPACE"


func add_hole(distance: float, lateral: float, hole_length: float, width: float) -> void:
	holes.append({"distance": distance, "lateral": lateral, "length": hole_length, "width": width})


## The hole under a point, or {} (on the ground, the swan falls through it).
func hole_at(distance: float, lateral: float) -> Dictionary:
	for hole in holes:
		if absf(between(hole.distance, distance)) < hole.length * 0.5 \
				and absf(lateral - hole.lateral) < hole.width * 0.5:
			return hole
	return {}


func add_puddle(distance: float, lateral: float, radius: float) -> void:
	puddles.append({"distance": distance, "lateral": lateral, "radius": radius})


## True when a point is in a puddle (on the ground it slows the swan down).
func in_puddle(distance: float, lateral: float) -> bool:
	for puddle in puddles:
		var along: float = between(puddle.distance, distance) / 1.6
		var across: float = lateral - puddle.lateral
		if along * along + across * across < puddle.radius * puddle.radius:
			return true
	return false


## The log right ahead in this lane (between `from` and `to` meters), or {}.
func log_ahead(distance: float, lateral: float, to: float, from := 0.0) -> Dictionary:
	for log in logs:
		var gap: float = ahead(distance, log.distance)
		if gap > from and gap < to and absf(lateral - log.lateral) < log.length * 0.5 + 0.8:
			return log
	return {}


## The nearest thing in the way (rock, tree, asteroid or animal) between `from`
## and `to` meters ahead, within `lane` meters of this lateral offset:
## {"d", "l", "r"}, or {} when the way is clear. Logs are left out (they are
## jumped); low rocks are in (a bot steers around them rather than jump).
func blocker_ahead(distance: float, lateral: float, to: float, from := 1.0, lane := 1.4) -> Dictionary:
	var best := {}
	var best_gap := INF
	var first := index_at(distance + from) / BUCKET
	var steps := int((to - from) / (BUCKET * _step)) + 2
	for k in steps:
		for n: int in _buckets.get(_wrap_bucket(first + k), []):
			var o := obstacles[n]
			if o.get("log", false):
				continue
			var gap: float = ahead(distance, o.d)
			if gap > from and gap < to and gap < best_gap and absf(o.l - lateral) < o.r + lane:
				best = {"d": o.d, "l": o.l, "r": o.r}
				best_gap = gap
	# Holes too: a bot would rather go around than risk the jump.
	for hole in holes:
		var gap: float = ahead(distance, hole.distance - hole.length * 0.5)
		if gap > from and gap < to and gap < best_gap \
				and absf(hole.lateral - lateral) < hole.width * 0.5 + lane:
			best = {"d": hole.distance, "l": hole.lateral, "r": hole.width * 0.5}
			best_gap = gap
	for mover in movers:
		var gap := ahead(distance, mover.distance)
		if gap > from and gap < to and gap < best_gap \
				and absf(mover.lateral - lateral) < mover.radius + lane:
			best = {"d": mover.distance, "l": mover.lateral, "r": mover.radius}
			best_gap = gap
	return best


## Where the podium goes: on the flat stretch past the finish line.
## Returns the distance where the row of blocks begins.
func podium_spot() -> float:
	return minf(finish_distance + 16.0, length - 30.0)
