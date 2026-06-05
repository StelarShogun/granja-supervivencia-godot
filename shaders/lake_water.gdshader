shader_type spatial;
// Stylized low-poly lake water.
// Opacity fades with water depth (distance to the geometry behind the surface),
// so the basin floor stays hidden in deep water while the shore reads translucent.
// Double-sided so the surface is still visible when the camera is underwater.
render_mode blend_mix, cull_disabled, depth_draw_always, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

uniform vec4 lake_color : source_color = vec4(0.10, 0.40, 0.48, 0.55);
uniform vec4 deep_color : source_color = vec4(0.02, 0.16, 0.24, 1.0);
uniform vec4 shore_glint : source_color = vec4(0.62, 0.88, 0.82, 0.34);
uniform float depth_distance = 5.0;   // meters of water needed to become fully opaque
uniform float shore_fade = 0.45;      // min alpha at the very edge
uniform float wave_speed = 0.08;
uniform float wave_height = 0.04;

varying float v_radial;

void vertex() {
	v_radial = clamp(length(UV - vec2(0.5)) * 2.0, 0.0, 1.0);
	float r = length(UV - vec2(0.5));
	VERTEX.y += sin((r * 24.0) - TIME * wave_speed * 20.0) * wave_height;
	VERTEX.y += sin((UV.x + UV.y) * 18.0 + TIME * wave_speed * 9.0) * wave_height * 0.45;
}

void fragment() {
	// Reconstruct linear scene depth of the geometry behind this fragment.
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float scene_depth = -view.z;
	float surface_depth = -VERTEX.z;
	float water_depth = max(scene_depth - surface_depth, 0.0);
	float fade = clamp(water_depth / depth_distance, 0.0, 1.0);

	// Discard where the water plane is on/above the ground so the shore has no
	// flat translucent slab — the lake only shows where it actually has depth.
	if (water_depth < 0.06) discard;

	float ripple = sin((UV.x * 18.0 + UV.y * 23.0) + TIME * wave_speed * 30.0) * 0.08;
	vec3 color = mix(lake_color.rgb, deep_color.rgb, fade);
	color = mix(color, shore_glint.rgb, smoothstep(0.68, 1.0, v_radial) * 0.30 + ripple * 0.2);
	ALBEDO = color;
	ALPHA = clamp(0.18 + fade, 0.0, 1.0);
	ROUGHNESS = 0.38;
	SPECULAR = 0.4;
}
