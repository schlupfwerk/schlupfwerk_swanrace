class_name CourseRules
extends RefCounted
## Terrain rules of a point-to-point course, applied to every swan after each
## tick. The same for players and bots (the course counterpart of TrackRules).
##   - Snow: the swan skis (SwanMotor.skiing); on the road it runs.
##   - Side fences and guard rails: the swan slides along them and loses the
##     part of its speed going into them (no daze: the road has many curves;
##     except solid walls, CourseTrack.daze_sides: running into one dazes).
##   - Trees, rocks, logs and animals: running into one, the swan stops and
##     pops up right past it, blinking (like on the island). Brushing one from
##     the side only slides along it. Rocks and logs can be jumped.
##   - Puddles: wet and slow (half the top speed) while running through.
##   - Open edges and holes (space, ADR 0024; broken parapets on the Great
##     Wall, ADR 0028): no fence there. Off such an edge, or on
##     the ground over a hole, the swan falls, screaming, and comes back on
##     the course a few seconds later, blinking (like drowning on the island).
##   - Never the wrong way.

const SWAN_RADIUS := 0.45
## How far past an obstacle a swan that ran into it reappears (meters).
const PAST_OBSTACLE := 1.2
## Speed kept when running straight into a fence (scaled by how straight).
const FENCE_LOSS := 0.8
## Walls that daze (CourseTrack.daze_sides): how straight into the wall
## (sine of the angle, ~5°) a swan must run to be dazed; less only slides.
const FENCE_DAZE_ANGLE := 0.08
## Top speed while splashing through a puddle (a share of the normal one).
const PUDDLE_SPEED := 0.5
## Top speed just before sinking into a soft edge (a share of the normal one).
const SAND_SLOWEST := 0.2
## How far past an open edge the swan's center may go before it falls (m):
## a foot over the edge is fine.
const FALL_MARGIN := 0.2


static func apply(swan: Swan, tracker: CourseTracker, track: CourseTrack) -> void:
	if swan.is_drowning():
		return
	var i := tracker.hint
	var distance := tracker.distance
	var lateral := tracker.lateral
	var race_heading := track.heading_at(i)
	var ground := track.ground_height_at(distance, lateral)
	swan.ground_y = ground
	swan.motor.skiing = track.terrain(distance) == CourseTrack.Terrain.SNOW
	# Puddles: jump them, or splash through and slow down.
	var splashing := swan.motor.on_ground and track.in_puddle(distance, lateral)
	swan.in_water = splashing
	swan.motor.max_speed_scale = PUDDLE_SPEED if splashing else 1.0
	_follow_ground(swan, track, i, ground)
	if track.soft_edges and _sink_in_sand(swan, track, i, lateral, race_heading):
		return
	if track.open_edges or not track.breaks.is_empty() or not track.holes.is_empty():
		if _fall_off(swan, track, i, distance, lateral, race_heading):
			return
	if not track.open_edges and not track.soft_edges:
		_keep_inside(swan, track, i, distance, lateral, race_heading)
	_collide(swan, track, i, distance)

	var off := wrapf(swan.motor.heading - race_heading, -PI, PI)
	if absf(off) > CourseTrack.MAX_WRONG_ANGLE:
		swan.motor.heading = race_heading + signf(off) * CourseTrack.MAX_WRONG_ANGLE


## No fences: past an edge, or on the ground over a hole, the swan falls.
## It comes back on the center line (off an edge) or just past the hole.
## Returns true when it fell.
static func _fall_off(swan: Swan, track: CourseTrack, i: int, distance: float, lateral: float,
		race_heading: float) -> bool:
	var off_edge := (lateral < track.left_edge(i) - FALL_MARGIN and track.edge_open(distance, -1.0)) \
			or (lateral > track.right_edge(i) + FALL_MARGIN and track.edge_open(distance, 1.0))
	var hole := {} if off_edge or not swan.motor.on_ground else track.hole_at(distance, lateral)
	if not off_edge and hole.is_empty():
		return false
	var at := distance
	var back_lateral := 0.0
	if not hole.is_empty():
		at = hole.distance + hole.length * 0.5 + 2.0
		back_lateral = clampf(lateral, track.left_edge(i) + 1.5, track.right_edge(i) - 1.5)
	var spot := track.index_at(at)
	var p := track.edge(spot, back_lateral)
	swan.fall(Vector3(p.x, 0.0, p.y), track.heading_at(spot) if not hole.is_empty() else race_heading)
	return true


## Soft sand past the edges: the higher up the dune, the slower; too far up,
## the swan sinks (drowns in the sand) and comes back on the course.
## Returns true when it sank.
static func _sink_in_sand(swan: Swan, track: CourseTrack, i: int, lateral: float,
		race_heading: float) -> bool:
	var outside := maxf(lateral - track.right_edge(i), track.left_edge(i) - lateral)
	if outside <= 0.0:
		return false
	if outside > track.sink_depth:
		var back := track.edge(i, clampf(lateral, track.left_edge(i) + 1.5, track.right_edge(i) - 1.5))
		swan.drown(Vector3(back.x, 0.0, back.y), race_heading)
		return true
	swan.motor.max_speed_scale *= lerpf(1.0, SAND_SLOWEST, clampf(outside / track.sink_depth, 0.0, 1.0))
	return false


## Fences on the slope, guard rails on the road: slide along, losing speed.
static func _keep_inside(swan: Swan, track: CourseTrack, i: int, distance: float, lateral: float,
		race_heading: float) -> void:
	var low := track.left_edge(i) + SWAN_RADIUS
	var high := track.right_edge(i) - SWAN_RADIUS
	if lateral >= low and lateral <= high:
		return
	var side := 1.0 if lateral > high else -1.0
	# A broken stretch of the fence: nothing to hold the swan (it may fall).
	if track.edge_open(distance, side):
		return
	var back := track.edge(i, clampf(lateral, low, high))
	swan.motor.position.x = back.x
	swan.motor.position.z = back.y
	var outward := track.right(i) * side
	var forward := Vector2(swan.motor.forward().x, swan.motor.forward().z)
	var into := forward.dot(outward)
	# Solid walls, curbs and fences (CourseTrack.daze_sides): running into one dazes
	# the swan, like the forest edge on the island. Brushing it only slides.
	if side in track.daze_sides and into > FENCE_DAZE_ANGLE and not swan.is_stunned():
		var inside := track.edge(i, clampf(lateral, low + 0.4, high - 0.4))
		swan.motor.position.x = inside.x
		swan.motor.position.z = inside.y
		swan.bump(race_heading)
		return
	if into > 0.0:
		swan.motor.speed *= 1.0 - FENCE_LOSS * into
		# Turned back along the fence.
		swan.motor.heading = lerp_angle(swan.motor.heading, race_heading, 0.3)


## Trees, rocks, logs and animals.
static func _collide(swan: Swan, track: CourseTrack, i: int, distance: float) -> void:
	var p := Vector2(swan.motor.position.x, swan.motor.position.z)
	for obstacle in track.obstacles_near(i):
		if _hit(swan, track, p, obstacle.p, obstacle.r, obstacle.h, obstacle.d):
			return
	for mover in track.movers_near(distance):
		if _hit(swan, track, p, mover.p, mover.radius, mover.height, mover.distance):
			return


## One solid thing at `center`. Returns true when the swan was moved past it.
static func _hit(swan: Swan, track: CourseTrack, p: Vector2, center: Vector2, radius: float,
		height: float, at: float) -> bool:
	var reach := radius + SWAN_RADIUS
	var away := p - center
	if away.length_squared() >= reach * reach or swan.motor.position.y >= height:
		return false
	var forward := Vector2(swan.motor.forward().x, swan.motor.forward().z)
	if forward.dot(center - p) > 0.0:
		var here := track.locate(p, track.index_at(at))
		var past := minf(at + reach + PAST_OBSTACLE, track.length - 1.0)
		var spot := track.index_at(past)
		var lateral: float = here["lateral"]
		# Never inside the thing it just passed (an animal may stand there).
		if absf(lateral - track.locate(center, spot)["lateral"]) < reach:
			lateral += reach if lateral >= 0.0 else -reach
		lateral = clampf(lateral, track.left_edge(spot) + 1.0, track.right_edge(spot) - 1.0)
		var edge := track.edge(spot, lateral)
		# Height 0: on the ground (SwanMotor keeps the height above the ground).
		swan.teleport(Vector3(edge.x, 0.0, edge.y), track.heading_at(spot))
		return true
	var normal := away.normalized() if away.length_squared() > 0.0001 else -forward
	p = center + normal * reach
	swan.motor.position.x = p.x
	swan.motor.position.z = p.y
	# Lose only the part of the speed going into it, and slide along.
	swan.motor.speed *= clampf(1.0 + forward.dot(normal), 0.0, 1.0)
	return false


## Slope under the swan: it changes speed (SwanMotor) and tilts the swan.
static func _follow_ground(swan: Swan, track: CourseTrack, i: int, ground: float) -> void:
	var p := Vector2(swan.motor.position.x, swan.motor.position.z)
	var forward := Vector2(swan.motor.forward().x, swan.motor.forward().z)
	var right := Vector2(-forward.y, forward.x)
	var ahead := track.locate(p + forward, i)
	var beside := track.locate(p + right, i)
	var grade := track.ground_height_at(ahead["distance"], ahead["lateral"]) - ground
	var cross := track.ground_height_at(beside["distance"], beside["lateral"]) - ground
	swan.motor.slope = grade if swan.motor.on_ground else 0.0
	swan.ground_pitch = atan(clampf(grade, -0.6, 0.6))
	swan.ground_roll = atan(clampf(cross, -0.6, 0.6))
