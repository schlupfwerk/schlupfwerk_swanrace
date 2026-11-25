class_name MeshKit
extends RefCounted
## Merges simple primitives into one vertex-colored mesh, so a whole tree is a
## single mesh that a MultiMesh can draw hundreds of times cheaply.


static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func add(st: SurfaceTool, mesh: PrimitiveMesh, xform: Transform3D, color: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := xform.basis.inverse().transposed()
	for index in indices:
		st.set_color(color)
		st.set_normal((normal_basis * normals[index]).normalized())
		st.add_vertex(xform * vertices[index])


static func finish(st: SurfaceTool) -> ArrayMesh:
	return st.commit()


## Toon material that takes its color from the mesh (and MultiMesh tint).
static func vertex_color_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	# Colors are written as sRGB hex values.
	mat.vertex_color_is_srgb = true
	# Soft, wrapped light (no hard toon bands).
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	return mat


static func sphere(radius: float, radial := 8, rings := 5) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial
	mesh.rings = rings
	return mesh


static func cylinder(bottom: float, top: float, height: float, radial := 7) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = radial
	mesh.rings = 1
	return mesh
