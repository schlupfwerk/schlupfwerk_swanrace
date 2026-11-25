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
## The painted backdrop panel: how far behind, how tall, horizon height.
const BACKDROP_DISTANCE := 70.0
const BACKDROP_HEIGHT := 155.0
const BACKDROP_EYE := 4.5
## How much of the drone's sweep the backdrop follows (0 = fixed, 1 = glued).
const BACKDROP_FOLLOW := 0.6

## Final standings, best first: {"name", "look", "time"}.
var standings: Array[Dictionary] = []
## The map's painted podium backdrop (assets/tracks/<map>/podium_background.png).
## The podium stands on its own stage in front of it, away from the 3D map.
var backdrop: Texture2D
## Ground height under a point of the row (local x), so blocks never sink.
var ground_at: Callable = func(_x: float) -> float: return 0.0

var _camera := Camera3D.new()
var _angle := 0.0
var _distance := 10.0
## Middle of the row, where the drone looks.
var _center_x := 0.0
var _center_y := 0.0
var _models: Array[SwanModel] = []
var _trophy: Node3D
var _backdrop: MeshInstance3D
var _backdrop_y := 0.0
var _trophy_base := Vector3.ZERO


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
		mesh.size = Vector3(BLOCK.x, block_height(place), BLOCK.z)
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
	_build_backdrop()
	_camera.fov = 55.0
	# Only the podium: nothing of the map behind it gets drawn.
	_camera.far = 150.0
	# The standings fill the bottom of the screen: the podium goes up top.
	_camera.v_offset = -_distance * 0.05
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
	if _trophy:
		# Floating over the winner's head, turning slowly.
		_trophy.rotation.y += delta * 1.2
		_trophy.position = _trophy_base + Vector3(0, sin(_angle * 9.0) * 0.08, 0)
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
	# The backdrop turns with part of the sweep: the scene still moves around the
	# podium, but the edges of the picture never come into view.
	if _backdrop:
		var turn := swing * BACKDROP_FOLLOW
		_backdrop.position = Vector3(_center_x - sin(turn) * BACKDROP_DISTANCE, _backdrop_y,
				-cos(turn) * BACKDROP_DISTANCE)
		_backdrop.rotation.y = turn


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
	if place == 1 and not celebrating:
		_add_trophy(at + Vector3(0, 2.85, 0))
	var label := Label3D.new()
	label.text = "%dº  %s\n%s" % [place, entry.name, Hud.format_time(entry.time)]
	label.font_size = 52 if place <= 3 else 40
	label.outline_size = 14
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Neighbors' names at two heights, so they don't overlap.
	label.position = at + Vector3(0, 3.1 + (0.45 if place % 2 == 0 and place > 3 else 0.0), 0)
	if place == 1:
		# Above the trophy.
		label.position.y += 0.9
	add_child(label)
	_models.append(model)


## The painted background is a big panel far behind the podium, part of the
## scene: the podium stays put on it and only the camera moves. Plus an
## invisible floor that only shows the shadows.
func _build_backdrop() -> void:
	if backdrop:
		var height := BACKDROP_HEIGHT
		var quad := QuadMesh.new()
		quad.size = Vector2(height * backdrop.get_width() / float(backdrop.get_height()), height)
		var picture := StandardMaterial3D.new()
		picture.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		picture.albedo_texture = backdrop
		picture.disable_fog = true
		var panel := MeshInstance3D.new()
		panel.mesh = quad
		panel.material_override = picture
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The painted horizon (about 42% from the top) at the drone's eye level.
		_backdrop_y = BACKDROP_EYE - 0.08 * height
		add_child(panel)
		_backdrop = panel
	var catcher := StandardMaterial3D.new()
	catcher.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	catcher.shadow_to_opacity = true
	catcher.albedo_color = Color("5a3a1a")
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 40)
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = plane
	floor_instance.material_override = catcher
	floor_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor_instance.position = Vector3(_center_x, 0.0, 0)
	add_child(floor_instance)


## A golden cup that floats over the winner's head.
func _add_trophy(at: Vector3) -> void:
	_trophy = Node3D.new()
	_trophy_base = at
	_trophy.position = at
	_trophy.scale = Vector3.ONE * 1.7
	add_child(_trophy)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = GOLD
	gold.metallic = 0.85
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = GOLD
	gold.emission_energy_multiplier = 0.15
	var parts := [
		# Mesh, position, rotation.
		[_cylinder(0.2, 0.09, 0.3), Vector3(0, 0.22, 0), Vector3.ZERO],
		[_cylinder(0.035, 0.035, 0.14), Vector3(0, 0.0, 0), Vector3.ZERO],
		[_cylinder(0.12, 0.14, 0.06), Vector3(0, -0.09, 0), Vector3.ZERO],
	]
	for side in [-1.0, 1.0]:
		var handle := TorusMesh.new()
		handle.inner_radius = 0.06
		handle.outer_radius = 0.085
		parts.append([handle, Vector3(0.2 * side, 0.24, 0), Vector3(PI / 2, 0, 0)])
	for part: Array in parts:
		var mesh := MeshInstance3D.new()
		mesh.mesh = part[0]
		mesh.material_override = gold
		mesh.position = part[1]
		mesh.rotation = part[2]
		_trophy.add_child(mesh)
	# A little sparkle around it.
	var light := OmniLight3D.new()
	light.light_color = Color("ffe9a0")
	light.light_energy = 0.6
	light.omni_range = 1.5
	_trophy.add_child(light)


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 18
	return mesh
