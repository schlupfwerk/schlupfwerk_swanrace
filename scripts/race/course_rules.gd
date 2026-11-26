class_name CourseRules
extends RefCounted
## Terrain rules of a point-to-point course, applied to every swan after each
## tick. The same for players and bots (the course counterpart of TrackRules).
##   - Snow: the swan skis (SwanMotor.skiing); on the road it runs.
##   - Side fences and guard rails: the swan slides along them and loses the
##     part of its speed going into them (no daze: the road has many curves).
##   - Trees, rocks, logs and animals: running into one, the swan stops and
##     pops up right past it, blinking (like on the island). Brushing one from
##     the side only slides along it. Rocks and logs can be jumped.
##   - Puddles: wet and slow (half the top speed) while running through.
##   - Never the wrong way.

const SWAN_RADIUS := 0.45
## How far past an obstacle a swan that ran into it reappears (meters).
const PAST_OBSTACLE := 1.2
## Speed kept when running straight into a fence (scaled by how straight).
const FENCE_LOSS := 0.8
## Top speed while splashing through a puddle (a share of the normal one).
const PUDDLE_SPEED := 0.5


static func apply(swan: Swan, tracker: CourseTracker, track: CourseTrack) -> void:
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
	_keep_inside(swan, track, i, lateral, race_heading)
	_collide(swan, track, i, distance)

	var off := wrapf(swan.motor.heading - race_heading, -PI, PI)
	if absf(off) > CourseTrack.MAX_WRONG_ANGLE:
		swan.motor.heading = race_heading + signf(off) * CourseTrack.MAX_WRONG_ANGLE


## Fences on the slope, guard rails on the road: slide along, losing speed.
static func _keep_inside(swan: Swan, track: CourseTrack, i: int, lateral: float,
		race_heading: float) -> void:
	var low := track.left_edge(i) + SWAN_RADIUS
	var high := track.right_edge(i) - SWAN_RADIUS
	if lateral >= low and lateral <= high:
		return
	var side := 1.0 if lateral > high else -1.0
	var back := track.edge(i, clampf(lateral, low, high))
	swan.motor.position.x = back.x
	swan.motor.position.z = back.y
	var outward := track.right(i) * side
	var forward := Vector2(swan.motor.forward().x, swan.motor.forward().z)
	var into := forward.dot(outward)
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
