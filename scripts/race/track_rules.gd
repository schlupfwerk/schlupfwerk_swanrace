class_name TrackRules
extends RefCounted
## Terrain rules of the island beach, applied to every swan after each tick.
## The same for players and bots.
##   - Water: wet and slow, the swan sinks as the sea gets deeper; deeper than
##     half its body it drowns and comes back on the racing line at 0 km/h.
##   - Forest edge and solid things (rocks, logs): bump, speed to 0, a daze,
##     then the swan turns back towards the race direction. Logs can be jumped.
##   - Never the wrong way: the heading stays within MAX_WRONG_ANGLE of the
##     race direction.

## Radius of a swan's body on the ground, for collisions.
const SWAN_RADIUS := 0.45
## Below this speed a touch only nudges the swan away, without a bump.
const BUMP_SPEED := 2.0
## Two swans closer than this push each other apart.
const SWAN_GAP := 1.15


static func apply(swan: Swan, laps: LapTracker, track: IslandTrack) -> void:
	if swan.is_drowning():
		return
	var i := laps.hint
	var lateral := laps.lateral
	var race_heading := track.heading_at(i)

	var ground := track.ground_height_at(laps.distance, lateral)
	swan.ground_y = ground
	# Wet where there is water: the sea, or the shallow lake (not its bridges).
	var in_lake := track.in_lake_water(laps.distance, lateral)
	var in_water := ground < IslandTrack.SEA_LEVEL + 0.15 or in_lake
	# Speed pads push only when the swan runs over them.
	if swan.motor.on_ground and track.on_booster(laps.distance, lateral) and swan.motor.pad_time <= 0.0:
		swan.hit_pad()
	swan.motor.max_speed_scale = IslandTrack.WATER_SPEED_SCALE if in_water else 1.0
	swan.in_water = in_water
	_follow_ground(swan, track, i, ground)
	if not in_lake and IslandTrack.SEA_LEVEL - ground > IslandTrack.DROWN_DEPTH:
		var center := track.points[i]
		swan.drown(Vector3(center.x, 0.0, center.y), race_heading)
		return

	if lateral < track.forest_edge(i) - 0.8 and not swan.is_stunned():
		var back := track.edge(i, track.forest_edge(i) + 0.6)
		swan.motor.position.x = back.x
		swan.motor.position.z = back.y
		swan.bump(race_heading)

	_collide(swan, track, i, race_heading)

	var off := wrapf(swan.motor.heading - race_heading, -PI, PI)
	if absf(off) > IslandTrack.MAX_WRONG_ANGLE:
		swan.motor.heading = race_heading + signf(off) * IslandTrack.MAX_WRONG_ANGLE


## Pushes the swan out of rocks and logs; a fast hit is a bump.
static func _collide(swan: Swan, track: IslandTrack, i: int, race_heading: float) -> void:
	var p := Vector2(swan.motor.position.x, swan.motor.position.z)
	for obstacle in track.obstacles_near(i):
		var center: Vector2 = obstacle.p
		var reach: float = obstacle.r + SWAN_RADIUS
		var away := p - center
		if away.length_squared() >= reach * reach or swan.motor.position.y >= obstacle.h:
			continue
		var normal := away.normalized() if away.length_squared() > 0.0001 \
				else -Vector2(swan.motor.forward().x, swan.motor.forward().z)
		p = center + normal * reach
		swan.motor.position.x = p.x
		swan.motor.position.z = p.y
		if swan.motor.speed > BUMP_SPEED and not swan.is_stunned():
			swan.bump(race_heading)
		else:
			# Slow contact: lose only the part of the speed going into it, so the
			# swan can slide along and walk around.
			var forward := Vector2(swan.motor.forward().x, swan.motor.forward().z)
			swan.motor.speed *= clampf(1.0 + forward.dot(normal), 0.0, 1.0)


## Slope under the swan: it changes speed (SwanMotor) and tilts the swan.
static func _follow_ground(swan: Swan, track: IslandTrack, i: int, ground: float) -> void:
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


## Swans have a body: when two touch, they push each other apart a little and
## both lose a bit of speed, like a gentle bump.
static func push_apart(swans: Array[Swan]) -> void:
	for a in swans.size():
		for b in range(a + 1, swans.size()):
			var sa := swans[a]
			var sb := swans[b]
			if sa.is_drowning() or sb.is_drowning():
				continue
			var away := Vector2(sb.motor.position.x - sa.motor.position.x,
					sb.motor.position.z - sa.motor.position.z)
			var gap := away.length()
			if gap >= SWAN_GAP or absf(sa.motor.position.y - sb.motor.position.y) > 0.8:
				continue
			var push := (away / maxf(gap, 0.01)) * (SWAN_GAP - gap) * 0.5
			sa.motor.position -= Vector3(push.x, 0.0, push.y)
			sb.motor.position += Vector3(push.x, 0.0, push.y)
			sa.motor.speed *= 0.985
			sb.motor.speed *= 0.985
