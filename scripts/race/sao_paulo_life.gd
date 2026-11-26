class_name SaoPauloLife
extends Node3D
## Life in São Paulo that doesn't touch the race: the drizzle ("garoa"), fine
## streaks of rain that follow the camera, and cyclists riding along the bike
## lane in the median, one lane each way (Brazil keeps to the right).

const CYCLISTS := 12
const DRIZZLE_AMOUNT := 2200

var _riders: Array[Dictionary] = []
var _drizzle: GPUParticles3D


func _ready() -> void:
	_build_drizzle()
	var rng := RandomNumberGenerator.new()
	rng.seed = 554
	var half := SaoPauloCircuit.STRAIGHT * 0.5 - 4.0
	for n in CYCLISTS:
		var east := n % 2 == 0
		var body := MeshInstance3D.new()
		body.mesh = RioScenery._cyclist_mesh(rng)
		body.material_override = MeshKit.vertex_color_material()
		add_child(body)
		_riders.append({
			"node": body,
			"x": rng.randf_range(-half, half),
			# Keep right: going east (+x) on the +z lane, west on the -z lane.
			"z": SaoPauloCircuit.BIKE_HALF * 0.5 * (1.0 if east else -1.0),
			"speed": rng.randf_range(4.5, 6.5) * (1.0 if east else -1.0),
		})
	_move_riders(0.0)


func _process(delta: float) -> void:
	_move_riders(delta)
	var camera := get_viewport().get_camera_3d()
	if camera:
		_drizzle.global_position = camera.global_position + Vector3.UP * 12.0


func _move_riders(delta: float) -> void:
	var half := SaoPauloCircuit.STRAIGHT * 0.5 - 4.0
	for rider: Dictionary in _riders:
		rider.x = wrapf(rider.x + rider.speed * delta, -half, half)
		var node: Node3D = rider.node
		node.position = Vector3(rider.x, 0.17, rider.z)
		node.rotation.y = -PI / 2.0 if rider.speed > 0.0 else PI / 2.0


## Fine, light rain: many thin, faint streaks falling almost straight down
## in a box around the camera.
func _build_drizzle() -> void:
	_drizzle = GPUParticles3D.new()
	_drizzle.amount = DRIZZLE_AMOUNT
	_drizzle.lifetime = 1.4
	_drizzle.preprocess = 1.4
	_drizzle.local_coords = false
	_drizzle.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 50, 80))
	_drizzle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(30.0, 1.0, 30.0)
	process.direction = Vector3(0.08, -1.0, 0.03)
	process.spread = 2.0
	process.initial_velocity_min = 12.0
	process.initial_velocity_max = 15.0
	process.gravity = Vector3(0.0, -4.0, 0.0)
	_drizzle.process_material = process
	var streak := QuadMesh.new()
	streak.size = Vector2(0.012, 0.45)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.88, 0.92, 0.35)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.material = mat
	_drizzle.draw_pass_1 = streak
	add_child(_drizzle)
