class_name RioTraffic
extends Node3D
## Life around Rio's seafront (decoration only, nothing collides): ships
## sailing slowly out at sea (a cargo ship, a cruise ship, sailboats and
## fishing boats), and now and then a plane crossing the sky: an airliner up
## high or a small plane towing an ad banner low along the beach.

const SHIPS := ["cargo", "cruise", "sail", "sail", "fishing", "cargo", "sail", "fishing"]
## Ships wrap around this far along the coast from the middle of the bay.
const SEA_SPAN := 1700.0

var course: RioCourse

var _rng := RandomNumberGenerator.new()
var _origin := Vector2.ZERO
var _along := Vector2.UP
var _side := Vector2.RIGHT
var _ships: Array[Dictionary] = []
var _planes: Array[Dictionary] = []
var _next_plane := 5.0


func _ready() -> void:
	_rng.seed = 2016
	var mid := course.sample_count() / 2
	_origin = course.points[mid]
	_along = course.tangent(mid)
	_side = course.right(mid)
	for n in SHIPS.size():
		var kind: String = SHIPS[n]
		var ship := MeshInstance3D.new()
		ship.mesh = _ship_mesh(kind)
		ship.material_override = MeshKit.vertex_color_material()
		ship.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ship)
		var near := kind == "sail" or kind == "fishing"
		_ships.append({
			"node": ship,
			"along": _rng.randf_range(-SEA_SPAN, SEA_SPAN),
			"lateral": _rng.randf_range(160.0, 420.0) if near else _rng.randf_range(550.0, 1300.0),
			"speed": (_rng.randf_range(3.0, 6.0) if near else _rng.randf_range(5.0, 8.0))
					* (1.0 if _rng.randf() < 0.5 else -1.0),
		})
	_move_ships(0.0)


func _process(delta: float) -> void:
	_move_ships(delta)
	_next_plane -= delta
	if _next_plane <= 0.0:
		_launch_plane()
		_next_plane = _rng.randf_range(18.0, 40.0)
	for plane: Dictionary in _planes.duplicate():
		plane.t += delta
		var u: float = plane.t / plane.duration
		if u >= 1.0:
			(plane.node as Node3D).queue_free()
			_planes.erase(plane)
			continue
		(plane.node as Node3D).position = (plane.from as Vector3).lerp(plane.to, u)


func _move_ships(delta: float) -> void:
	for ship: Dictionary in _ships:
		ship.along = wrapf(ship.along + ship.speed * delta, -SEA_SPAN, SEA_SPAN)
		var p: Vector2 = _origin + _along * ship.along + _side * ship.lateral
		var node: Node3D = ship.node
		node.position = Vector3(p.x, 0.0, p.y)
		node.rotation.y = _yaw(_along * signf(ship.speed))
		# A gentle roll on the swell.
		node.rotation.z = 0.025 * sin(Time.get_ticks_msec() * 0.0011 + ship.lateral)


func _launch_plane() -> void:
	var banner := _rng.randf() < 0.4
	var forward := 1.0 if _rng.randf() < 0.5 else -1.0
	var lateral := _rng.randf_range(55.0, 90.0) if banner else _rng.randf_range(150.0, 900.0)
	var height := _rng.randf_range(40.0, 55.0) if banner else _rng.randf_range(170.0, 320.0)
	var reach := 1400.0 if banner else 2000.0
	var speed := 32.0 if banner else 80.0
	var a: Vector2 = _origin + _along * (-reach * forward) + _side * lateral
	var b: Vector2 = _origin + _along * (reach * forward) + _side * (lateral + _rng.randf_range(-150.0, 150.0))
	var plane := MeshInstance3D.new()
	plane.mesh = _banner_plane_mesh() if banner else _airliner_mesh()
	plane.material_override = MeshKit.vertex_color_material()
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plane.rotation.y = _yaw(b - a)
	add_child(plane)
	_planes.append({
		"node": plane,
		"from": Vector3(a.x, height, a.y),
		"to": Vector3(b.x, height, b.y),
		"t": 0.0,
		"duration": a.distance_to(b) / speed,
	})


## The yaw that turns a mesh facing -Z towards `dir`.
static func _yaw(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)


# --- Meshes (all facing -Z) ------------------------------------------------------

static func _ship_mesh(kind: String) -> Mesh:
	var st := MeshKit.begin()
	match kind:
		"cargo":
			_box(st, Vector3(16, 6, 120), Vector3(0, 1.5, 0), Color("7a2a24"))
			_box(st, Vector3(16.2, 1.2, 120.2), Vector3(0, 4.0, 0), Color("1f2a36"))
			_box(st, Vector3(14, 12, 12), Vector3(0, 10.0, 46), Color("f2f2f2"))
			_box(st, Vector3(3, 6, 3), Vector3(0, 19.0, 48), Color("e8412c"))
			var colors := [Color("2a6fd1"), Color("e8a33a"), Color("3fbf6a"), Color("c0392b"), Color("8a5cf6")]
			for row in 7:
				for col in 3:
					for layer in 2:
						_box(st, Vector3(4.6, 2.6, 11.5), Vector3(-5 + col * 5, 6.0 + layer * 2.7, -42 + row * 12.5),
								colors[(row * 3 + col + layer) % colors.size()])
		"cruise":
			_box(st, Vector3(22, 8, 160), Vector3(0, 2.0, 0), Color("f4f4f2"))
			_box(st, Vector3(22.2, 1.6, 160.2), Vector3(0, 2.0, 0), Color("1d3f8a"))
			for deck in 4:
				var length := 130.0 - deck * 16.0
				_box(st, Vector3(19 - deck * 1.5, 3.0, length), Vector3(0, 7.5 + deck * 3.0, 6 + deck * 4.0),
						Color("f4f4f2"))
				_box(st, Vector3(19.2 - deck * 1.5, 0.7, length * 0.95), Vector3(0, 7.8 + deck * 3.0, 6 + deck * 4.0),
						Color("2f4a63"))
			_box(st, Vector3(6, 7, 10), Vector3(0, 22, 30), Color("1d3f8a"))
		"sail":
			_box(st, Vector3(2.4, 1.2, 9), Vector3(0, 0.4, 0), Color("f4f4f2"))
			_box(st, Vector3(0.15, 12, 0.15), Vector3(0, 7.0, -0.5), Color("dddddd"))
			var sail := PrismMesh.new()
			sail.size = Vector3(6.0, 11.0, 0.08)
			sail.left_to_right = 1.0
			MeshKit.add(st, sail, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0, 6.8, 2.5)), Color("ffffff"))
		_:
			_box(st, Vector3(4, 1.8, 13), Vector3(0, 0.6, 0), Color("2a6fd1"))
			_box(st, Vector3(4.1, 0.4, 13.1), Vector3(0, 1.4, 0), Color("f2f2f2"))
			_box(st, Vector3(3, 2.5, 3.5), Vector3(0, 2.8, 2.5), Color("f2f2f2"))
			_box(st, Vector3(0.15, 5, 0.15), Vector3(0, 4.0, -2.5), Color("dddddd"))
	return MeshKit.finish(st)


static func _airliner_mesh() -> Mesh:
	var st := MeshKit.begin()
	var white := Color("f4f4f2")
	var blue := Color("1d4f9a")
	MeshKit.add(st, MeshKit.cylinder(2.0, 2.0, 32.0, 12), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO), white)
	MeshKit.add(st, MeshKit.sphere(2.0, 12, 6), IslandScenery._at(Vector3(0, 0, -16), Vector3(1, 1, 1.6)), white)
	MeshKit.add(st, MeshKit.cylinder(2.0, 0.5, 7.0, 12), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.6, 19.5)),
			white)
	_box(st, Vector3(34, 0.5, 6), Vector3(0, -0.8, -1), white)
	_box(st, Vector3(12, 0.4, 3), Vector3(0, 1.0, 21), white)
	_box(st, Vector3(0.5, 7, 4.5), Vector3(0, 4.3, 20.5), blue)
	_box(st, Vector3(4.1, 0.6, 30), Vector3(0, 0.6, 0), blue)
	for x: float in [-7.0, 7.0]:
		MeshKit.add(st, MeshKit.cylinder(0.9, 0.9, 4.0, 10), Transform3D(Basis(Vector3.RIGHT, PI / 2),
				Vector3(x, -1.8, -3.0)), Color("c8c8c8"))
	return MeshKit.finish(st)


## A small propeller plane towing a long banner behind it.
static func _banner_plane_mesh() -> Mesh:
	var st := MeshKit.begin()
	var red := Color("e8412c")
	MeshKit.add(st, MeshKit.cylinder(0.7, 0.4, 7.0, 10), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO),
			Color("f4f4f2"))
	_box(st, Vector3(10, 0.25, 1.6), Vector3(0, 0.6, -0.8), red)
	_box(st, Vector3(3.2, 0.2, 1.0), Vector3(0, 0.2, 3.2), red)
	_box(st, Vector3(0.2, 1.5, 1.2), Vector3(0, 0.9, 3.2), red)
	_box(st, Vector3(0.1, 1.8, 0.2), Vector3(0, 0, -3.6), Color("333333"))
	# The tow line and the banner: yellow cloth with a few colored blocks of "text".
	_box(st, Vector3(0.05, 0.05, 10), Vector3(0, 0, 8.5), Color("dddddd"))
	_box(st, Vector3(0.1, 3.0, 22), Vector3(0, -0.6, 25), Color("ffd23f"))
	for n in 6:
		_box(st, Vector3(0.14, 1.4, 2.4), Vector3(0, -0.6, 16.5 + n * 3.3), Color("1d3f8a") if n % 2 else red)
	return MeshKit.finish(st)


static func _box(st: SurfaceTool, size: Vector3, center: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	MeshKit.add(st, box, Transform3D(Basis.IDENTITY, center), color)
