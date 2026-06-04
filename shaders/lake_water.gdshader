shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 lake_color : source_color = vec4(0.10, 0.40, 0.48, 0.58);
uniform vec4 deep_color : source_color = vec4(0.03, 0.19, 0.27, 0.70);
uniform vec4 shore_glint : source_color = vec4(0.62, 0.88, 0.82, 0.34);
uniform float wave_speed = 0.08;
uniform float wave_height = 0.04;


void vertex() {
	float r = length(UV - vec2(0.5));
	VERTEX.y += sin((r * 24.0) - TIME * wave_speed * 20.0) * wave_height;
	VERTEX.y += sin((UV.x + UV.y) * 18.0 + TIME * wave_speed * 9.0) * wave_height * 0.45;
}


void fragment() {
	float r = clamp(length(UV - vec2(0.5)) * 2.0, 0.0, 1.0);
	float ripple = sin((UV.x * 18.0 + UV.y * 23.0) + TIME * wave_speed * 30.0) * 0.08;
	vec3 color = mix(deep_color.rgb, lake_color.rgb, r + ripple);
	color = mix(color, shore_glint.rgb, smoothstep(0.68, 1.0, r) * 0.35);
	ALBEDO = color;
	ALPHA = mix(deep_color.a, lake_color.a, r);
	ROUGHNESS = 0.38;
	SPECULAR = 0.4;
}
