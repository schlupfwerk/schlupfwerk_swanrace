class_name Sailboat
extends Node3D
## A small sailboat drifting slowly around the island, far out at sea.

var orbit_radius := 400.0
var angle := 0.0
## Radians per second around the island (negative = the other way).
var speed := 0.006
var sail_color := Color("f7f3e8")


func _ready() -> void:
	var hull_mat := SwanModel._toon(Color("8a4b2c"))
	var hull := MeshInstance3D.new()
	hull.mesh = MeshKit.sphere(1.0, 10, 5)
	hull.scale = Vector3(1.2, 0.5, 3.4)
	hull.position.y = 0.1
	hull.material_override = hull_mat
	add_child(hull)
	var mast := MeshInstance3D.new()
	mast.mesh = MeshKit.cylinder(0.08, 0.06, 7.0, 6)
	mast.position = Vector3(0, 3.8, -0.4)
	mast.material_override = SwanModel._toon(Color("d9d2c3"))
	add_child(mast)
	# Triangular sail: a 3-sided cone flattened into a sheet.
	var sail := MeshInstance3D.new()
	sail.mesh = MeshKit.cylinder(2.0, 0.0, 6.2, 3)
	sail.position = Vector3(0, 3.8, 0.9)
	sail.scale = Vector3(0.06, 1.0, 1.0)
	var sail_mat := SwanModel._toon(sail_color)
	sail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sail.material_override = sail_mat
	add_child(sail)


func _process(delta: float) -> void:
	angle += speed * delta
	var p := Vector3(cos(angle), 0.0, sin(angle)) * orbit_radius
	position = Vector3(p.x, IslandTrack.SEA_LEVEL + sin(Time.get_ticks_msec() * 0.0012) * 0.15, p.z)
	# Face the direction of travel and rock gently on the waves.
	rotation.y = -angle + (PI if speed > 0.0 else 0.0)
	rotation.z = sin(Time.get_ticks_msec() * 0.0009) * 0.06
