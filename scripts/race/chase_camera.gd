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

var _yaw := 0.0
var _height := 0.0


func _ready() -> void:
	top_level = true
	fov = 68.0
	far = 600.0
	if target:
		_yaw = target.rotation.y
		_place()


func _process(delta: float) -> void:
	if target == null:
		return
	_yaw = lerp_angle(_yaw, target.rotation.y, 1.0 - exp(-5.0 * delta))
	_height = lerpf(_height, target.global_position.y * JUMP_FOLLOW, 1.0 - exp(-6.0 * delta))
	_place()
	var target_fov := 68.0 + 14.0 * target.motor.speed_ratio()
	fov = lerpf(fov, target_fov, 1.0 - exp(-4.0 * delta))


func _place() -> void:
	var basis := Basis(Vector3.UP, _yaw)
	var ground := Vector3(target.global_position.x, _height, target.global_position.z)
	global_position = ground + basis * Vector3(0, HEIGHT, DISTANCE)
	look_at(ground + Vector3.UP * LOOK_HEIGHT + basis * Vector3(0, 0, -LOOK_AHEAD))
