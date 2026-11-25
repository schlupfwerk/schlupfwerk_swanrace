class_name Podium
extends Node3D
## End of race: the top three on a podium with medals, and the last swan in
## front proudly biting its (participation) medal.

const GOLD := Color("f2c418")
const SILVER := Color("c9ccd3")
const BRONZE := Color("cd7f32")
## Podium blocks: x offset and height for 1st, 2nd, 3rd.
const BLOCKS := [[0.0, 1.1], [-2.3, 0.75], [2.3, 0.45]]

## Final standings, best first: {"name", "look", "time"}.
var standings: Array[Dictionary] = []

var _camera := Camera3D.new()
var _angle := 0.0


func _ready() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("f3efe2")
	stone.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	var medals := [GOLD, SILVER, BRONZE]
	for place in mini(3, standings.size()):
		var block: Array = BLOCKS[place]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.0, block[1], 1.8)
		var box := MeshInstance3D.new()
		box.mesh = mesh
		box.material_override = stone
		box.position = Vector3(block[0], block[1] / 2.0, 0)
		add_child(box)
		var number := Label3D.new()
		number.text = str(place + 1)
		number.font_size = 160
		number.outline_size = 24
		number.pixel_size = 0.004
		number.modulate = medals[place]
		number.position = Vector3(block[0], block[1] * 0.5, 0.91)
		add_child(number)
		var last := place == standings.size() - 1 and standings.size() > 1
		_add_swan(standings[place], Vector3(block[0], block[1], 0), medals[place], last, place + 1)
	# The last one (if not already on the podium) stands in front with its medal.
	if standings.size() > 3:
		_add_swan(standings[standings.size() - 1], Vector3(3.6, 0.0, 2.4), BRONZE, true,
				standings.size())
	_camera.fov = 55.0
	add_child(_camera)
	_camera.make_current()
	_place_camera()


func _process(delta: float) -> void:
	_angle += delta * 0.22
	_place_camera()


func _place_camera() -> void:
	# A drone sweeping 180°, from one side of the podium to the other and back.
	var swing := sin(_angle) * PI / 2.0
	_camera.position = Vector3(sin(swing) * 10.0, 3.6, cos(swing) * 10.0)
	_camera.look_at(global_position + Vector3(0, 1.6, 0.5))


func _add_swan(entry: Dictionary, at: Vector3, medal: Color, bite: bool, place: int) -> void:
	var model := SwanModel.new()
	model.position = at
	# Facing the camera (+Z).
	model.rotation.y = PI
	add_child(model)
	model.apply_look(entry.look)
	model.expression = SwanModel.Face.LAUGH if place == 1 or bite else SwanModel.Face.HAPPY
	if bite:
		model.bite_medal(GOLD if place == 1 else medal)
	else:
		model.hang_medal(medal)
	model.set_process(false)
	var label := Label3D.new()
	label.text = "%dº  %s\n%s" % [place, entry.name, Hud.format_time(entry.time)]
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# The one biting its medal has the name at its feet, out of the podium's way.
	label.position = at + (Vector3(0, 0.2, 1.1) if bite and at.y == 0.0 else Vector3(0, 3.3, 0))
	add_child(label)
	_models.append(model)


var _models: Array[SwanModel] = []


func _physics_process(delta: float) -> void:
	# Idle animation: breathing, blinking and the medal bite.
	for model in _models:
		model.animate(delta, 0.0, 0.0, 0.0, 0.0, true)
