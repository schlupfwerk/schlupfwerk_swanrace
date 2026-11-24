shader_type spatial;
// Cartoon feathers: one color, or a vertical gradient over the whole swan.
render_mode diffuse_toon, specular_toon;

uniform vec3 color_bottom : source_color = vec3(1.0);
uniform vec3 color_top : source_color = vec3(1.0);
uniform bool use_gradient = false;
// World height of the swan's feet, updated every frame by SwanModel.
uniform float root_y = 0.0;
uniform float bottom_y = 0.75;
uniform float top_y = 2.55;

varying float height_t;

void vertex() {
	float world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	height_t = clamp((world_y - root_y - bottom_y) / (top_y - bottom_y), 0.0, 1.0);
}

void fragment() {
	ALBEDO = use_gradient ? mix(color_bottom, color_top, height_t) : color_bottom;
	ROUGHNESS = 0.6;
	RIM = 0.25;
	RIM_TINT = 0.5;
}
