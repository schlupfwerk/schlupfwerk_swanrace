shader_type spatial;
// Fabric layer over the swan: soft lighting, the hem swings and trails
// behind with speed. UV.x goes around the body, UV.y from the top (0) to the
// hem (1), so the bottom moves the most.
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec3 color : source_color = vec3(0.8);
// 0 = still, 1 = running fast: how far the hem trails back and flutters.
uniform float sway = 0.0;
// How loose the garment is (a tank top is 0, a jacket 1).
uniform float looseness = 1.0;
// Quilted lines (winter jacket).
uniform float quilt = 0.0;
uniform float roughness_value = 0.75;

void vertex() {
	float hem = UV.y * UV.y * looseness;
	float flutter = sin(TIME * 7.0 + UV.x * 18.0) * 0.012 + sin(TIME * 3.1 + UV.x * 7.0) * 0.01;
	VERTEX.z += hem * (0.03 + sway * 0.14);
	VERTEX.x += hem * flutter * (0.4 + sway);
	VERTEX.y += hem * sway * 0.03;
}

void fragment() {
	vec3 c = color;
	if (quilt > 0.0) {
		float line = 1.0 - smoothstep(0.0, 0.08, abs(fract(UV.y * 5.0) - 0.5) - 0.42);
		c *= 1.0 - 0.18 * quilt * line;
	}
	// A darker inside, so the open front reads as a separate layer.
	ALBEDO = FRONT_FACING ? c : c * 0.55;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.3;
	RIM = 0.15;
	RIM_TINT = 0.6;
}
