shader_type spatial;
// Bird legs: soft shading with thin dark scale lines, like chicken feet.
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec3 color : source_color = vec3(0.17);
uniform float scale_lines = 14.0;

void fragment() {
	float band = abs(fract(UV.y * scale_lines) - 0.5);
	float line = 1.0 - smoothstep(0.03, 0.09, band);
	vec3 dark = color * 0.35;
	ALBEDO = mix(color, dark, line * 0.9);
	ROUGHNESS = 0.6;
	SPECULAR = 0.25;
	RIM = 0.12;
}
