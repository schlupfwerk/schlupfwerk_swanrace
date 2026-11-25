class_name ChaseCamera
extends Camera3D
## Follows a swan from behind at a fixed distance (no lag at top speed).
## Only the turn and the jump height are smoothed. FOV widens with speed.

const DISTANCE := 5.6
const HEIGHT := 2.7
const LOOK_HEIGHT := 1.7
const LOOK_AHEAD := 4.0
const JUMP_FOLLOW := 0.5

var target: Swan
## After the finish: the camera pulls away and circles the swan.
var finish := false
## 0..1: how far to pull back for a wider view (set by the race near the lake
## bridges, so the holes to jump are easy to see). Eased in and out here.
var zoom_out := 0.0

var _finish_time := 0.0
## Smoothed slope under the swan: the camera dips on climbs.
var _slope := 0.0

var _yaw := 0.0
var _height := 0.0
var _zoom := 0.0


func _ready() -> void:
	top_level = true
	fov = Settings.fov
	far = 600.0
	if target:
		_yaw = target.rotation.y
		_height = target.global_position.y
		_place()


func _process(delta: float) -> void:
	if target == null:
		return
	if finish:
		_finish_time += delta
		_yaw += delta * 0.35
	else:
		_yaw = lerp_angle(_yaw, target.rotation.y, 1.0 - exp(-5.0 * delta))
	# Follow the ground fully (hills), but only half of a jump.
	var ground := target.global_position.y - target.motor.position.y
	_height = lerpf(_height, ground + target.motor.position.y * JUMP_FOLLOW, 1.0 - exp(-6.0 * delta))
	_place()
	_slope = lerpf(_slope, target.motor.slope, 1.0 - exp(-3.0 * delta))
	_zoom = lerpf(_zoom, zoom_out, 1.0 - exp(-1.5 * delta))
	var target_fov := Settings.fov + 8.0 * target.motor.speed_ratio() + (6.0 if target.motor.boosting else 0.0)
	fov = lerpf(fov, target_fov, 1.0 - exp(-4.0 * delta))


func _place() -> void:
	var basis := Basis(Vector3.UP, _yaw)
	var ground := Vector3(target.global_position.x, _height, target.global_position.z)
	var away := smoothstep(0.0, 3.0, _finish_time)
	# Climbing: lower and closer, looking up the hill. Descending: a bit higher.
	var climb := clampf(_slope * 6.0, -0.6, 1.0)
	var height := HEIGHT - 1.3 * maxf(climb, 0.0) + 0.6 * maxf(-climb, 0.0) + 3.2 * _zoom
	var distance := DISTANCE - 0.8 * maxf(climb, 0.0) + 4.5 * _zoom
	global_position = ground + basis * Vector3(0, lerpf(height, 9.0, away),
			lerpf(distance, 18.0, away))
	look_at(ground + Vector3.UP * (LOOK_HEIGHT + 1.2 * maxf(climb, 0.0))
			+ basis * Vector3(0, 0, -LOOK_AHEAD - 4.0 * _zoom))
