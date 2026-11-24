shader_type spatial;
// Cartoon sea: rolling waves, turquoise near the island, deeper blue far away.
render_mode diffuse_toon, specular_toon;

uniform vec3 shallow_color : source_color = vec3(0.22, 0.74, 0.78);
uniform vec3 deep_color : source_color = vec3(0.06, 0.36, 0.62);
// Rough distance from the island center to the shore, for the color only.
uniform float shore_radius = 170.0;

varying float wave_height;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = world_position.xz;
	float h = sin(p.x * 0.08 + TIME * 1.1) * 0.18
			+ sin(p.y * 0.11 - TIME * 1.4) * 0.14
			+ sin((p.x + p.y) * 0.21 + TIME * 2.0) * 0.06;
	VERTEX.y += h;
	wave_height = h;
}

void fragment() {
	float depth = clamp((length(world_position.xz) - shore_radius) / 140.0, 0.0, 1.0);
	vec3 color = mix(shallow_color, deep_color, depth);
	color = mix(color, vec3(1.0), smoothstep(0.24, 0.36, wave_height) * 0.45);
	ALBEDO = color;
	ROUGHNESS = 0.2;
	SPECULAR = 0.6;
}
