shader_type spatial;
// Speed pad: glowing chevrons sliding forward. UV.y runs along the track.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 color_a : source_color = vec3(1.0, 0.85, 0.2);
uniform vec3 color_b : source_color = vec3(1.0, 0.45, 0.1);

void fragment() {
	vec2 uv = UV;
	// Chevrons: arrow tips pointing forward (-Z, the small UV.y side), repeated
	// along the pad and sliding forward.
	float v = uv.y * 3.0 - abs(uv.x - 0.5) * 1.6 + TIME * 2.2;
	float stripe = smoothstep(0.35, 0.45, fract(v)) * (1.0 - smoothstep(0.75, 0.85, fract(v)));
	float edge = smoothstep(0.0, 0.08, uv.x) * smoothstep(1.0, 0.92, uv.x);
	ALBEDO = mix(color_b, color_a, stripe);
	ALPHA = (0.55 + 0.4 * stripe) * edge;
}
