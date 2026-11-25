shader_type spatial;
// Tinted glasses lens: one color or a vertical gradient, see-through.
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec3 color_top : source_color = vec3(0.56, 0.76, 1.0);
uniform vec3 color_bottom : source_color = vec3(0.56, 0.76, 1.0);

varying float lens_y;

void vertex() {
	// Height inside the lens, whatever its shape or rotation.
	lens_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - NODE_POSITION_WORLD.y;
}

void fragment() {
	float t = clamp(lens_y / 0.12 + 0.5, 0.0, 1.0);
	ALBEDO = mix(color_bottom, color_top, t);
	ALPHA = 0.65;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
}
