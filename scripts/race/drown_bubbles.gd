class_name DrownBubbles
extends Node3D
## Five air bubbles that rise in a zig-zag from a drowning swan and pop,
## each with a little sound.

const COUNT := 5
const RISE_TIME := 1.1
const SPACING := 0.28

var _bubbles: Array[Dictionary] = []
var _pop_player := AudioStreamPlayer3D.new()


func _ready() -> void:
	top_level = true
	_pop_player.stream = Sfx.pop()
	_pop_player.bus = &"SFX"
	_pop_player.max_polyphony = COUNT
	add_child(_pop_player)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.rim_enabled = true
	mat.rim = 1.0
	mat.roughness = 0.1
	for n in COUNT:
		var mesh := MeshInstance3D.new()
		mesh.mesh = MeshKit.sphere(0.12, 12, 6)
		mesh.material_override = mat
		mesh.visible = false
		add_child(mesh)
		_bubbles.append({"mesh": mesh, "t": -1.0, "from": Vector3.ZERO, "side": 1.0})


## Starts the bubbles from `at` (the swan's head under water).
func release(at: Vector3) -> void:
	for n in COUNT:
		var bubble := _bubbles[n]
		bubble.t = -SPACING * n
		bubble.from = at + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
		bubble.side = 1.0 if n % 2 == 0 else -1.0


func _process(delta: float) -> void:
	for bubble in _bubbles:
		var mesh: MeshInstance3D = bubble.mesh
		if bubble.t >= RISE_TIME:
			continue
		bubble.t += delta
		var t: float = bubble.t
		if t < 0.0:
			continue
		if t >= RISE_TIME:
			# Pop!
			mesh.visible = false
			_pop_player.global_position = mesh.global_position
			_pop_player.pitch_scale = randf_range(0.85, 1.25)
			_pop_player.play()
			continue
		var u := t / RISE_TIME
		mesh.visible = true
		mesh.global_position = bubble.from + Vector3(
				sin(u * TAU * 1.5) * 0.35 * bubble.side, u * 2.4, cos(u * TAU * 1.5) * 0.15)
		# Grows a little, then swells just before popping.
		var grow := 0.6 + 0.6 * u + (0.5 * smoothstep(0.85, 1.0, u))
		mesh.scale = Vector3.ONE * grow
