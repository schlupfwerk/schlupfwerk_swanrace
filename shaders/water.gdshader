shader_type spatial;
// Cartoon sea: rolling waves, turquoise near the island fading to deep blue,
// drifting color patches, crest highlights and sun glints.
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.12, 0.48, 0.55);
uniform vec3 mid_color : source_color = vec3(0.08, 0.44, 0.62);
uniform vec3 deep_color : source_color = vec3(0.05, 0.3, 0.56);
// Rough distance from the island center to the shore, for the color only.
uniform float shore_radius = 280.0;

varying float wave_height;
varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = world_position.xz;
	float h = sin(p.x * 0.08 + TIME * 1.1) * 0.16
			+ sin(p.y * 0.11 - TIME * 1.4) * 0.12
			+ sin((p.x + p.y) * 0.21 + TIME * 2.0) * 0.06
			+ sin((p.x - p.y) * 0.05 + TIME * 0.6) * 0.1;
	VERTEX.y += h;
	wave_height = h;
}

void fragment() {
	vec2 p = world_position.xz;
	float distance_out = length(p) - shore_radius;
	float depth = clamp(distance_out / 220.0, 0.0, 1.0);
	vec3 color = mix(shallow_color, mid_color, smoothstep(0.0, 0.35, depth));
	color = mix(color, deep_color, smoothstep(0.35, 1.0, depth));
	// Slow drifting patches of lighter and darker water.
	float patches = noise(p * 0.015 + vec2(TIME * 0.01, -TIME * 0.007));
	patches += 0.5 * noise(p * 0.05 - vec2(TIME * 0.02, 0.0));
	color *= 0.9 + 0.16 * patches;
	// White crests and tiny glints.
	color = mix(color, vec3(1.0), smoothstep(0.26, 0.4, wave_height) * 0.5);
	float glint = step(0.985, noise(p * 0.9 + TIME * 0.8)) * step(0.0, wave_height);
	color = mix(color, vec3(1.0), glint * 0.7);
	ALBEDO = color;
	ROUGHNESS = 0.18;
	SPECULAR = 0.45;
}
