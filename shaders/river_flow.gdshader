shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.16, 0.48, 0.44, 0.62);
uniform vec4 deep_color : source_color = vec4(0.04, 0.25, 0.32, 0.74);
uniform vec4 foam_color : source_color = vec4(0.82, 0.95, 0.88, 0.55);
uniform float flow_speed = 0.18;
uniform float ripple_strength = 0.055;
uniform float foam_edge = 0.18;


void vertex() {
	VERTEX.y += sin((UV.y * 18.0) + TIME * flow_speed * 24.0) * ripple_strength;
}


float wave_noise(vec2 uv) {
	float a = sin((uv.y * 38.0) + TIME * flow_speed * 30.0);
	float b = sin((uv.y * 17.0 + uv.x * 11.0) - TIME * flow_speed * 18.0);
	return a * 0.5 + b * 0.5;
}


void fragment() {
	float edge = smoothstep(0.5 - foam_edge, 0.5, abs(UV.x - 0.5));
	float wave = wave_noise(UV);
	vec3 color = mix(shallow_color.rgb, deep_color.rgb, clamp(UV.y * 0.08 + wave * 0.12, 0.0, 1.0));
	color = mix(color, foam_color.rgb, edge * (0.45 + wave * 0.15));
	ALBEDO = color;
	ALPHA = mix(shallow_color.a, deep_color.a, 0.55) + edge * 0.12;
	ROUGHNESS = 0.32;
	SPECULAR = 0.45;
}
