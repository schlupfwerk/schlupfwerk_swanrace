shader_type spatial;
// Waves of foam rolling onto the beach. UV.y: 0 = open sea, 1 = shore.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float speed = 0.22;
uniform float bands = 3.0;

void fragment() {
	float v = UV.y;
	float band = fract(v * bands - TIME * speed + sin(UV.x * 40.0) * 0.04);
	float wave = smoothstep(0.82, 0.97, band) * smoothstep(0.0, 0.35, v);
	float shore = smoothstep(0.82, 1.0, v) * (0.65 + 0.35 * sin(TIME * 1.3 + UV.x * 25.0));
	ALBEDO = vec3(1.0);
	ALPHA = clamp(max(wave, shore), 0.0, 1.0) * 0.85;
}
