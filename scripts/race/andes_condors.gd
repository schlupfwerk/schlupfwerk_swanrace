class_name AndesCondors
extends Node3D
## Condors gliding in wide, slow circles over the Andes valley (decoration).

## Middle of each condor's circle, in world space.
var centers := PackedVector3Array()

var _birds: Array[Node3D] = []
var _time := 0.0


func _ready() -> void:
	var mesh := _condor_mesh()
	for n in centers.size():
		var bird := MeshInstance3D.new()
		bird.mesh = mesh
		bird.material_override = MeshKit.vertex_color_material()
		bird.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bird)
		_birds.append(bird)


func _process(delta: float) -> void:
	_time += delta
	for n in _birds.size():
		var radius := 45.0 + n * 12.0
		var angle := _time * (0.12 + n * 0.02) + n * 1.7
		var bird := _birds[n]
		bird.position = centers[n] + Vector3(cos(angle) * radius, 4.0 * sin(_time * 0.3 + n), sin(angle) * radius)
		# Facing along the circle, banked into the turn.
		bird.rotation = Vector3(0.0, PI - angle, 0.25)


## A condor facing -Z: black body, white collar, long wide wings with
## fingered tips.
static func _condor_mesh() -> Mesh:
	var st := MeshKit.begin()
	var black := Color("1d1d22")
	MeshKit.add(st, MeshKit.sphere(0.5, 8, 5), IslandScenery._at(Vector3.ZERO, Vector3(0.7, 0.6, 2.2)), black)
	MeshKit.add(st, MeshKit.sphere(0.3, 8, 4), IslandScenery._at(Vector3(0, 0.1, -1.0)), Color("f2efe8"))
	MeshKit.add(st, MeshKit.sphere(0.22, 8, 4), IslandScenery._at(Vector3(0, 0.15, -1.3)), Color("c9876e"))
	for side: float in [-1.0, 1.0]:
		var wing := BoxMesh.new()
		wing.size = Vector3(3.2, 0.08, 1.1)
		MeshKit.add(st, wing, Transform3D(Basis(Vector3.BACK, side * 0.08), Vector3(side * 1.8, 0.1, 0.0)), black)
		for f in 4:
			var finger := BoxMesh.new()
			finger.size = Vector3(0.7, 0.05, 0.16)
			MeshKit.add(st, finger, IslandScenery._at(Vector3(side * 3.6, 0.2, -0.4 + f * 0.27)), black)
	return MeshKit.finish(st)
