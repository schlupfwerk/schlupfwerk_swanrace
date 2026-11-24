shader_type spatial;
// Cartoon feathers: one color or a vertical gradient over the whole swan,
// with rows of scalloped feather edges so the plumage reads as feathers.
render_mode diffuse_toon, specular_toon;

uniform vec3 color_bottom : source_color = vec3(1.0);
uniform vec3 color_top : source_color = vec3(1.0);
uniform bool use_gradient = false;
// World height of the swan's feet, updated every frame by SwanModel.
uniform float root_y = 0.0;
uniform float bottom_y = 0.75;
uniform float top_y = 2.55;
// Feather rows around (x) and along (y) each part.
uniform vec2 feather_rows = vec2(26.0, 13.0);
uniform float feather_contrast = 0.14;

varying float height_t;

void vertex() {
	float world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	height_t = clamp((world_y - root_y - bottom_y) / (top_y - bottom_y), 0.0, 1.0);
}

void fragment() {
	vec3 color = use_gradient ? mix(color_bottom, color_top, height_t) : color_bottom;
	// Scallops: offset every other row, darken the rim of each feather.
	vec2 grid = UV * feather_rows;
	float row = floor(grid.y);
	grid.x += mod(row, 2.0) * 0.5;
	vec2 cell = fract(grid) - vec2(0.5, 0.05);
	float d = length(cell * vec2(1.0, 1.5));
	float rim = 1.0 - smoothstep(0.0, 0.07, abs(d - 0.5));
	// Fade out near the poles of each part, where UVs bunch up.
	float away_from_poles = smoothstep(0.08, 0.25, UV.y) * smoothstep(0.92, 0.75, UV.y);
	rim *= away_from_poles;
	float shade = mix(1.0, mix(1.0, 0.9, clamp(cell.y, 0.0, 1.0)), away_from_poles);
	ALBEDO = color * shade * (1.0 - feather_contrast * rim);
	ROUGHNESS = 0.65;
	RIM = 0.3;
	RIM_TINT = 0.5;
}
