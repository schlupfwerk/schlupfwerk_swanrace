class_name CourseMover
extends Node3D
## An animal that walks around on a course: a goat wandering on the ski slope,
## a deer or a cow crossing the road. It lives in course coordinates
## (distance along the course, lateral offset) and moves on a fixed pattern
## of the race clock, so it is the same for every swan. Solid like a rock
## (CourseRules), too tall to jump.
##
## Patterns:
##   - WANDER: drifts back and forth across a band, slowly going up and down
##     the slope a little.
##   - CROSS: walks from one side to the other, waits a moment, walks back.
##   - STROLL: walks along the course (`reach` meters each way), turns around.

enum Pattern { WANDER, CROSS, STROLL }

var track: CourseTrack
## What animal it is ("goat", "cow", "deer"...): the scenery builds its body.
var kind := ""
var pattern := Pattern.WANDER
## Where it lives: distance along the course and the middle of its band.
var home_distance := 0.0
var home_lateral := 0.0
## Half the width it walks across (m), and its walking speed (m/s).
var reach := 6.0
var walk_speed := 1.2
## Seconds it waits at each side (CROSS).
var pause := 2.0
## Shifts the pattern in time, so animals don't move in step.
var phase := 0.0
var radius := 0.7
var height := 1.4

## Where it is now (updated by advance).
var distance := 0.0
var lateral := 0.0
## Its place on the ground, for collisions.
var p := Vector2.ZERO

var _facing := 0.0
var _last_lateral := 0.0


func _ready() -> void:
	advance(0.0)


## Puts the animal where the pattern says it is at race time `t` (seconds).
func advance(t: float) -> void:
	var time := t + phase
	_last_lateral = lateral
	match pattern:
		Pattern.WANDER:
			var omega := walk_speed / maxf(reach, 0.5)
			lateral = home_lateral + reach * sin(time * omega)
			distance = home_distance + 2.0 * sin(time * omega * 0.37 + 1.3)
		Pattern.CROSS:
			# One crossing takes `walk`, then a pause, then back.
			var walk := 2.0 * reach / maxf(walk_speed, 0.1)
			var cycle := 2.0 * (walk + pause)
			var u := fposmod(time, cycle)
			var across := 0.0
			if u < walk:
				across = u / walk
			elif u < walk + pause:
				across = 1.0
			elif u < 2.0 * walk + pause:
				across = 1.0 - (u - walk - pause) / walk
			lateral = home_lateral - reach + 2.0 * reach * smoothstep(0.0, 1.0, across)
			distance = home_distance
		Pattern.STROLL:
			var walk := 2.0 * reach / maxf(walk_speed, 0.1)
			var u := fposmod(time, 2.0 * walk) / walk
			var along := u if u < 1.0 else 2.0 - u
			distance = home_distance - reach + 2.0 * reach * along
			lateral = home_lateral + 0.4 * sin(time * 0.7)
	var i := track.index_at(distance)
	p = track.edge(i, lateral)
	position = Vector3(p.x, track.ground_height_at(distance, lateral), p.y)
	# Face the way it walks: across the course, or along it (STROLL).
	if pattern == Pattern.STROLL:
		var ahead := fposmod(time, 4.0 * reach / maxf(walk_speed, 0.1)) < 2.0 * reach / maxf(walk_speed, 0.1)
		_facing = track.heading_at(i) + (0.0 if ahead else PI)
	else:
		var moved := lateral - _last_lateral
		if absf(moved) > 0.0005:
			var across_dir := track.right(i) * signf(moved)
			_facing = atan2(-across_dir.x, -across_dir.y)
	rotation.y = lerp_angle(rotation.y, _facing, 0.2)
