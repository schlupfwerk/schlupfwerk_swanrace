class_name Podium
extends Node3D
## End of race: one numbered block per racer (12 racers, 12 places). The
## 2-1-3 podium, then 4th, 5th... stepping down to the right. Gold, silver and bronze medals
## for the top three; the last one celebrates as if it had won: a "1" medal,
## a bottle spraying foam, winking and laughing (SwanModel.celebrate).
## Everyone dances lightly. A drone sweeps 60° in front of it, back and forth.

const GOLD := Color("f2c418")
const SILVER := Color("c9ccd3")
const BRONZE := Color("cd7f32")
## Heights of the first three blocks; from 4th on they keep stepping down.
const TOP_HEIGHTS := [1.1, 0.8, 0.6]
const LOW_START := 0.45
const LOW_STEP := 0.035
const LOW_MIN := 0.12
const SPACING := 1.9
const BLOCK := Vector3(1.6, 1.0, 1.6)

## Final standings, best first: {"name", "look", "time"}.
var standings: Array[Dictionary] = []
## Ground height under a point of the row (local x), so blocks never sink.
var ground_at: Callable = func(_x: float) -> float: return 0.0

var _camera := Camera3D.new()
var _angle := 0.0
var _distance := 10.0
## Middle of the row, where the drone looks.
var _center_x := 0.0
var _center_y := 0.0
var _models: Array[SwanModel] = []


func _ready() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("f3efe2")
	stone.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	var count := standings.size()
	var medals := [GOLD, SILVER, BRONZE]
	for place in count:
		var x := block_x(place)
		# Each block stands on the sand right under it (and reaches into it).
		var floor_y: float = ground_at.call(x)
		var height := floor_y + block_height(place)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(BLOCK.x, block_height(place) + 1.0, BLOCK.z)
		var box := MeshInstance3D.new()
		box.mesh = mesh
		box.material_override = stone
		box.position = Vector3(x, height - mesh.size.y / 2.0, 0)
		add_child(box)
		var number := Label3D.new()
		number.text = str(place + 1)
		number.font_size = 150 if place < 3 else 100
		number.outline_size = 24
		number.pixel_size = 0.004
		number.modulate = medals[place] if place < 3 else Color("5a5a66")
		number.position = Vector3(x, height - block_height(place) * 0.5, BLOCK.z / 2.0 + 0.01)
		add_child(number)
		var last := place == count - 1 and count > 1
		var medal: Color = medals[place] if place < 3 else Color.TRANSPARENT
		_add_swan(standings[place], Vector3(x, height, 0), medal, last, place + 1)
	# Far enough to see every block.
	_distance = maxf(9.0, 5.0 + count * 1.3)
	_center_x = (block_x(1) + block_x(maxi(count - 1, 2))) / 2.0
	_camera.fov = 55.0
	# The standings fill the bottom of the screen: the podium goes up top.
	_camera.v_offset = -_distance * 0.12
	_center_y = ground_at.call(_center_x)
	add_child(_camera)
	_camera.make_current()
	_place_camera()


## Classic 2-1-3 podium, then the rest stepping down to the right, so the
## last one always ends the row (and is easy to spot).
static func block_x(place: int) -> float:
	match place:
		0:
			return 0.0
		1:
			return -SPACING
	return (place - 1) * SPACING


static func block_height(place: int) -> float:
	if place < TOP_HEIGHTS.size():
		return TOP_HEIGHTS[place]
	return maxf(LOW_START - (place - TOP_HEIGHTS.size()) * LOW_STEP, LOW_MIN)


func _process(delta: float) -> void:
	_angle += delta * 0.22
	_place_camera()


func _physics_process(delta: float) -> void:
	# Idle animation: breathing, blinking, the celebration.
	for model in _models:
		model.animate(delta, 0.0, 0.0, 0.0, 0.0, true)


func _place_camera() -> void:
	# A drone sweeping 60° in front of the podium, back and forth.
	var swing := sin(_angle) * deg_to_rad(30.0)
	_camera.position = Vector3(_center_x + sin(swing) * _distance, _center_y + 2.6 + _distance * 0.12,
			cos(swing) * _distance)
	_camera.look_at(to_global(Vector3(_center_x, _center_y + 1.3, 0.3)))


func _add_swan(entry: Dictionary, at: Vector3, medal: Color, celebrating: bool, place: int) -> void:
	var model := SwanModel.new()
	model.position = at
	# Facing the camera (+Z).
	model.rotation.y = PI
	add_child(model)
	model.apply_look(entry.look)
	model.set_process(false)
	model.dancing = true
	if celebrating:
		model.expression = SwanModel.Face.LAUGH
		model.celebrate(GOLD)
	else:
		model.expression = SwanModel.Face.LAUGH if place == 1 else SwanModel.Face.HAPPY
		if medal.a > 0.0:
			model.hang_medal(medal)
	var label := Label3D.new()
	label.text = "%dº  %s\n%s" % [place, entry.name, Hud.format_time(entry.time)]
	label.font_size = 52 if place <= 3 else 40
	label.outline_size = 14
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Neighbors' names at two heights, so they don't overlap.
	label.position = at + Vector3(0, 3.1 + (0.45 if place % 2 == 0 and place > 3 else 0.0), 0)
	add_child(label)
	_models.append(model)
