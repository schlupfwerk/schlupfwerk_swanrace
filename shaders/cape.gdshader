shader_type spatial;
// Superhero cape: the mesh rests draped over the swan's back, from the
// shoulders to the tail. With speed it lifts and flies straight out behind,
// rippling. UV.x goes across the cape, UV.y from the shoulders (0) to the hem (1).
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec3 color : source_color = vec3(0.8);
// 0 = still, 1 = running fast (shared with the clothes).
uniform float sway = 0.0;
uniform float roughness_value = 0.75;
// Where the cape is tied and how big it is (set by swan_model.gd).
uniform float top_y = 0.46;
uniform float top_z = -0.24;
uniform float cape_length = 0.95;
uniform float width_top = 0.34;
uniform float width_hem = 0.78;

void vertex() {
	float v = UV.y;
	float speed = clamp(sway, 0.0, 1.0);
	// The knot at the shoulders stays put; the rest lifts with speed.
	float fly = speed * smoothstep(0.0, 0.3, v);
	vec3 flying = vec3((UV.x - 0.5) * mix(width_top, width_hem, v),
			top_y + 0.14 * v, top_z + v * cape_length);
	VERTEX = mix(VERTEX, flying, fly);
	// Waves running down the cape, bigger at the hem and the faster it goes.
	float wave = sin(TIME * 13.0 - v * 9.0 + UV.x * 2.0) * (0.03 + 0.07 * speed) * v;
	VERTEX.y += wave * fly;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), fly));
}

void fragment() {
	// A darker inside, so the lining reads as the back of the fabric.
	ALBEDO = FRONT_FACING ? color : color * 0.6;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.3;
	RIM = 0.15;
	RIM_TINT = 0.6;
}
