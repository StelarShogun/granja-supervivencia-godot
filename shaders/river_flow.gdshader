shader_type spatial;
// Stylized low-poly flowing river water.
// Opacity fades with water depth so the riverbed is hidden in the deep centre of
// the channel while the banks read shallow and translucent. Double-sided so the
// surface is visible from underneath.
render_mode blend_mix, cull_disabled, depth_draw_always, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

uniform vec4 shallow_color : source_color = vec4(0.16, 0.46, 0.44, 0.55);
uniform vec4 deep_color : source_color = vec4(0.03, 0.20, 0.26, 1.0);
uniform vec4 foam_color : source_color = vec4(0.82, 0.95, 0.88, 0.55);
uniform float depth_distance = 2.5;   // meters of water needed to become fully opaque
uniform float bank_fade = 0.40;       // min alpha at the bank edge
uniform float flow_speed = 0.18;
uniform float ripple_strength = 0.04;
uniform float foam_edge = 0.16;

void vertex() {
	VERTEX.y += sin((UV.y * 18.0) + TIME * flow_speed * 24.0) * ripple_strength;
}

float wave_noise(vec2 uv) {
	float a = sin((uv.y * 38.0) + TIME * flow_speed * 30.0);
	float b = sin((uv.y * 17.0 + uv.x * 11.0) - TIME * flow_speed * 18.0);
	return a * 0.5 + b * 0.5;
}

void fragment() {
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float scene_depth = -view.z;
	float surface_depth = -VERTEX.z;
	float water_depth = max(scene_depth - surface_depth, 0.0);
	float fade = clamp(water_depth / depth_distance, 0.0, 1.0);

	// Where the water plane lies on or above the ground there is no real depth,
	// so discard to avoid a flat translucent slab over the terrain. The river
	// then only appears inside the part of the channel it actually fills.
	if (water_depth < 0.06) discard;

	float edge = smoothstep(0.5 - foam_edge, 0.5, abs(UV.x - 0.5));
	float wave = wave_noise(UV);
	vec3 color = mix(shallow_color.rgb, deep_color.rgb, fade);
	color = mix(color, foam_color.rgb, edge * (0.40 + wave * 0.15));
	ALBEDO = color;
	ALPHA = clamp(0.15 + fade, 0.0, 1.0) + edge * 0.08;
	ROUGHNESS = 0.32;
	SPECULAR = 0.45;
}
