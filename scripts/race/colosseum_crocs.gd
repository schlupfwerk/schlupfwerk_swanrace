class_name ColosseumCrocs
extends Node3D
## Crocodiles in the pit in the middle of the Colosseum arena: they swim in
## slow loops in the water and snap their jaws now and then (decoration; the
## pit itself is what the swans fall into).

const COUNT := 7
const GREEN := Color("4f6b3a")
const BELLY := Color("a8b07a")

## The pit's half-length and half-width, and the water level.
var inner := Vector2(90.0, 60.0)
var water_y := 0.0

var _crocs: Array[Node3D] = []
var _jaws: Array[Node3D] = []
var _time := 0.0


func _ready() -> void:
	var body_mesh := _body_mesh()
	var jaw_mesh := _jaw_mesh()
	var mat := MeshKit.vertex_color_material()
	for n in COUNT:
		var croc := Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = body_mesh
		body.material_override = mat
		croc.add_child(body)
		var jaw := Node3D.new()
		jaw.position = Vector3(0.0, 0.35, -1.6)
		var jaw_body := MeshInstance3D.new()
		jaw_body.mesh = jaw_mesh
		jaw_body.material_override = mat
		jaw.add_child(jaw_body)
		croc.add_child(jaw)
		croc.scale = Vector3.ONE * (1.2 + 0.2 * (n % 3))
		add_child(croc)
		_crocs.append(croc)
		_jaws.append(jaw)


func _process(delta: float) -> void:
	_time += delta
	for n in _crocs.size():
		var speed := 0.05 + 0.015 * (n % 3)
		var lane := 0.35 + 0.5 * float(n) / COUNT
		var angle := _time * speed * (1.0 if n % 2 == 0 else -1.0) + TAU * n / COUNT
		var p := Vector3(cos(angle) * inner.x * lane, water_y - 0.15, sin(angle) * inner.y * lane)
		var croc := _crocs[n]
		var ahead := Vector3(-sin(angle) * inner.x, 0.0, cos(angle) * inner.y) * (1.0 if n % 2 == 0 else -1.0)
		croc.position = p
		croc.rotation.y = atan2(-ahead.x, -ahead.z) + 0.15 * sin(_time * 2.0 + n)
		# Snap: open wide quickly, close, every few seconds.
		var u := fmod(_time + n * 1.7, 4.0 + n % 3)
		_jaws[n].rotation.x = 0.7 * sin(u / 0.5 * PI) if u < 0.5 else 0.0


## Body facing -Z: a long flat body with ridges, legs, a tail and the lower jaw.
static func _body_mesh() -> Mesh:
	var st := MeshKit.begin()
	MeshKit.add(st, MeshKit.sphere(0.5, 10, 6), IslandScenery._at(Vector3(0, 0.2, 0.2), Vector3(1.4, 0.6, 3.6)), GREEN)
	MeshKit.add(st, MeshKit.cylinder(0.45, 0.05, 2.6, 8), IslandScenery._at(Vector3(0, 0.15, 2.6), Vector3(1.0, 0.5, 1.0),
			Vector3(PI / 2.0, 0, 0)), GREEN)
	for k in 6:
		var ridge := BoxMesh.new()
		ridge.size = Vector3(0.16, 0.16, 0.16)
		MeshKit.add(st, ridge, IslandScenery._at(Vector3(0, 0.52, -0.6 + k * 0.45)), GREEN.darkened(0.25))
	for x: float in [-0.65, 0.65]:
		for z: float in [-0.8, 0.9]:
			var leg := BoxMesh.new()
			leg.size = Vector3(0.35, 0.18, 0.4)
			MeshKit.add(st, leg, IslandScenery._at(Vector3(x, 0.05, z)), GREEN)
	# Lower jaw (it stays still).
	var lower := BoxMesh.new()
	lower.size = Vector3(0.5, 0.14, 1.3)
	MeshKit.add(st, lower, IslandScenery._at(Vector3(0, 0.22, -2.1)), BELLY)
	return MeshKit.finish(st)


## Upper jaw, hinged at the back (it opens): head, snout, eyes and teeth.
static func _jaw_mesh() -> Mesh:
	var st := MeshKit.begin()
	var head := BoxMesh.new()
	head.size = Vector3(0.55, 0.22, 1.4)
	MeshKit.add(st, head, IslandScenery._at(Vector3(0, 0.0, -0.6)), GREEN)
	for x: float in [-0.18, 0.18]:
		MeshKit.add(st, MeshKit.sphere(0.11, 6, 4), IslandScenery._at(Vector3(x, 0.16, 0.0)), Color("f2e26a"))
		MeshKit.add(st, MeshKit.sphere(0.05, 6, 3), IslandScenery._at(Vector3(x, 0.2, -0.06)), Color("1d1d22"))
	for k in 5:
		for x: float in [-0.24, 0.24]:
			var tooth := BoxMesh.new()
			tooth.size = Vector3(0.05, 0.1, 0.05)
			MeshKit.add(st, tooth, IslandScenery._at(Vector3(x, -0.12, -0.2 - k * 0.22)), Color("f4f1ea"))
	return MeshKit.finish(st)
