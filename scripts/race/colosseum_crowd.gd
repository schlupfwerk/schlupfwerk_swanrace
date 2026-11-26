class_name ColosseumCrowd
extends Node3D
## The spectators in the Colosseum stands: thousands of simple people drawn
## with a few MultiMeshes and one shader. They sway a little all the time;
## when the player completes a lap (cheer()), they jump with their arms up
## and the crowd roars for a few seconds. A soft murmur plays all along.

const CHEER_TIME := 3.5
const SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

uniform float cheer = 0.0;
varying vec3 tint;

void vertex() {
	float phase = INSTANCE_CUSTOM.a * 6.2832;
	float hop = max(sin(TIME * 13.0 + phase), 0.0);
	VERTEX.y += 0.04 * sin(TIME * 1.7 + phase) + cheer * 0.55 * hop;
	// White parts of the mesh are the shirt: each person has its own color.
	bool shirt = COLOR.r > 0.98 && COLOR.g > 0.98 && COLOR.b > 0.98;
	vec3 c = shirt ? INSTANCE_CUSTOM.rgb : COLOR.rgb;
	tint = pow(c, vec3(2.2));
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 1.0;
}
"""

var _material: ShaderMaterial
var _cheer := 0.0
var _roar: AudioStreamPlayer
var _murmur: AudioStreamPlayer


## Builds the people: `transforms` and shirt `colors`, one each.
func setup(transforms: Array[Transform3D], colors: Array[Color], rng: RandomNumberGenerator) -> void:
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	_material.shader = shader
	# One MultiMesh per skin tone.
	var skins: Array = RioScenery.SKIN
	var groups := []
	for n in skins.size():
		groups.append([])
	for k in transforms.size():
		groups[rng.randi_range(0, skins.size() - 1)].append(k)
	for n in skins.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _person_mesh(skins[n])
		mm.instance_count = groups[n].size()
		for m in groups[n].size():
			var k: int = groups[n][m]
			mm.set_instance_transform(m, transforms[k])
			var shirt: Color = colors[k]
			mm.set_instance_custom_data(m, Color(shirt.r, shirt.g, shirt.b, rng.randf()))
		var people := MultiMeshInstance3D.new()
		people.multimesh = mm
		people.material_override = _material
		people.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(people)


func _ready() -> void:
	_roar = AudioStreamPlayer.new()
	_roar.stream = Sfx.crowd_cheer()
	_roar.bus = &"SFX"
	add_child(_roar)
	_murmur = AudioStreamPlayer.new()
	_murmur.stream = Sfx.crowd_murmur()
	_murmur.bus = &"SFX"
	_murmur.volume_db = -16.0
	add_child(_murmur)
	_murmur.play()


## The crowd goes wild: jumps and roars.
func cheer() -> void:
	_cheer = CHEER_TIME
	_roar.play()


func _process(delta: float) -> void:
	if _cheer > 0.0:
		_cheer = maxf(_cheer - delta, 0.0)
	var strength := clampf(_cheer / 1.0, 0.0, 1.0) if _cheer < 1.0 else 1.0
	_material.set_shader_parameter("cheer", strength)


## A seated spectator facing -Z, arms up (white = shirt).
static func _person_mesh(skin: Color) -> Mesh:
	var st := MeshKit.begin()
	var body := BoxMesh.new()
	body.size = Vector3(0.5, 0.6, 0.4)
	MeshKit.add(st, body, IslandScenery._at(Vector3(0, 0.3, 0)), Color.WHITE)
	MeshKit.add(st, MeshKit.sphere(0.17, 7, 4), IslandScenery._at(Vector3(0, 0.78, 0)), skin)
	for x: float in [-0.3, 0.3]:
		var arm := BoxMesh.new()
		arm.size = Vector3(0.1, 0.5, 0.1)
		MeshKit.add(st, arm, IslandScenery._at(Vector3(x, 0.75, -0.05), Vector3.ONE, Vector3(0, 0, -signf(x) * 0.35)),
				skin)
	return MeshKit.finish(st)
