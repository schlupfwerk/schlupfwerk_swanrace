class_name Scenery
extends RefCounted
## Sky, sun and shared helpers for the scenery.
## Everything here is decoration: nothing collides with the swans.

const SAND := Color("bf9c6b")


static func add_environment(parent: Node) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4f8fe0")
	sky_material.sky_horizon_color = Color("bcd6ef")
	sky_material.ground_horizon_color = Color("d8c3a0")
	sky_material.ground_bottom_color = Color("8a6d4c")
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	# A soft glow and gentle contrast, so the scene reads smooth, not busy.
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("c9dbec")
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	# Low enough to be seen in the sky along part of the lap, with long shadows.
	sun.rotation_degrees = Vector3(-26, 150, 0)
	sun.light_angular_distance = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.light_energy = 1.0
	sun.shadow_blur = 1.6
	sun.shadow_opacity = 0.75
	# Shadows on/off and distance come from the video settings.
	sun.add_to_group("sun")
	Settings.configure_sun(sun)
	parent.add_child(sun)


static func flat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	return mat

