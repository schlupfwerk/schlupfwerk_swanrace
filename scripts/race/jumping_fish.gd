class_name JumpingFish
extends Node3D
## A few cartoon fish that leap out of the sea, with a splash, somewhere ahead
## of the swan you follow so they are actually seen. Decoration only.

const FISH_COUNT := 8
const JUMP_TIME := 1.1
const COLORS := [Color("ff8a2a"), Color("c9d6e3"), Color("3f8fd8"), Color("ffd23f")]

var track: IslandTrack
var follow: Swan

var _fish: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for n in FISH_COUNT:
		var body := _make_fish(COLORS[n % COLORS.size()])
		body.visible = false
		add_child(body)
		var splash := _make_splash()
		add_child(splash)
		_fish.append({"node": body, "splash": splash, "wait": _rng.randf_range(0.5, 4.0),
				"t": -1.0, "from": Vector3.ZERO, "dir": Vector3.ZERO, "length": 4.0,
				"height": 2.0})


func _process(delta: float) -> void:
	if track == null:
		return
	for fish in _fish:
		var node: Node3D = fish.node
		if fish.t < 0.0:
			fish.wait -= delta
			if fish.wait <= 0.0:
				_start_jump(fish)
			continue
		fish.t += delta / JUMP_TIME
		if fish.t >= 1.0:
			_splash(fish, fish.from + fish.dir * fish.length)
			node.visible = false
			fish.t = -1.0
			fish.wait = _rng.randf_range(0.8, 4.0)
			continue
		var u: float = fish.t
		var pos: Vector3 = fish.from + fish.dir * fish.length * u \
				+ Vector3.UP * (4.0 * fish.height * u * (1.0 - u))
		var velocity: Vector3 = fish.dir * fish.length + Vector3.UP * (4.0 * fish.height * (1.0 - 2.0 * u))
		node.position = pos
		node.look_at(pos + velocity, Vector3.UP)
		node.rotate_object_local(Vector3.FORWARD, sin(u * TAU * 2.0) * 0.3)


func _start_jump(fish: Dictionary) -> void:
	var base := 0
	if follow:
		base = track.locate(Vector2(follow.position.x, follow.position.z), -1)["index"]
	var i := base + _rng.randi_range(12, 70)
	var p := track.edge(i, _rng.randf_range(30.0, 70.0))
	for attempt in 6:
		if track.is_open_sea(p, 8.0):
			break
		i += 5
		p = track.edge(i, _rng.randf_range(30.0, 70.0))
	var yaw := _rng.randf() * TAU
	fish.from = Vector3(p.x, IslandScenery.SEA_LEVEL - 0.2, p.y)
	fish.dir = Vector3(cos(yaw), 0.0, sin(yaw))
	fish.length = _rng.randf_range(3.0, 5.0)
	fish.height = _rng.randf_range(1.5, 2.6)
	fish.t = 0.0
	(fish.node as Node3D).visible = true
	_splash(fish, fish.from)


func _splash(fish: Dictionary, at: Vector3) -> void:
	var splash: CPUParticles3D = fish.splash
	splash.position = Vector3(at.x, IslandScenery.SEA_LEVEL, at.z)
	splash.restart()


static func _make_fish(color: Color) -> Node3D:
	var root := Node3D.new()
	var mat := SwanModel._toon(color)
	var body := MeshInstance3D.new()
	body.mesh = MeshKit.sphere(0.5, 12, 6)
	body.scale = Vector3(0.28, 0.42, 0.9)
	body.material_override = mat
	root.add_child(body)
	var tail := MeshInstance3D.new()
	tail.mesh = MeshKit.cylinder(0.3, 0.0, 0.35, 4)
	tail.position = Vector3(0, 0, 0.55)
	tail.rotation = Vector3(-PI / 2, 0, 0)
	tail.scale = Vector3(0.25, 1.0, 1.0)
	tail.material_override = mat
	root.add_child(tail)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = MeshKit.sphere(0.05, 6, 4)
		eye.position = Vector3(0.12 * side, 0.06, -0.3)
		eye.material_override = SwanModel._toon(Color("151518"))
		root.add_child(eye)
	return root


static func _make_splash() -> CPUParticles3D:
	var splash := CPUParticles3D.new()
	splash.emitting = false
	splash.one_shot = true
	splash.explosiveness = 0.9
	splash.amount = 18
	splash.lifetime = 0.8
	splash.local_coords = false
	splash.mesh = SwanModel._particle_sphere(0.09)
	splash.direction = Vector3.UP
	splash.spread = 35.0
	splash.initial_velocity_min = 2.5
	splash.initial_velocity_max = 4.5
	splash.gravity = Vector3(0, -9.8, 0)
	splash.color_ramp = SwanModel._fade(Color(1, 1, 1, 0.9))
	return splash
