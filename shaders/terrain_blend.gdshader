shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D tex_grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform float uv_scale : hint_range(0.005, 0.1) = 0.025;
uniform float blend_sharpness : hint_range(1.0, 8.0) = 3.0;
uniform float noise_scale : hint_range(0.002, 0.04) = 0.012;

float hash2(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 19.31);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash2(i), hash2(i + vec2(1,0)), f.x),
		mix(hash2(i + vec2(0,1)), hash2(i + vec2(1,1)), f.x),
		f.y);
}

float terrain_noise(vec2 p) {
	float v = 0.0;
	v += noise2(p * 1.0) * 0.50;
	v += noise2(p * 2.1) * 0.30;
	v += noise2(p * 4.3) * 0.20;
	return v;
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wp = world_pos.xz;

	vec2 uv = wp * uv_scale;
	vec4 c_grass = texture(tex_grass, uv);
	vec4 c_dirt  = texture(tex_dirt,  uv);

	float n = terrain_noise(wp * noise_scale);
	// Boost contrast so blend is decisive but smooth at edges
	float t = clamp((n - 0.5) * blend_sharpness + 0.5, 0.0, 1.0);

	// Extra small-scale variation to break up uniformity
	float detail = terrain_noise(wp * noise_scale * 3.7) * 0.18;
	t = clamp(t + detail - 0.09, 0.0, 1.0);

	vec4 col = mix(c_dirt, c_grass, t);
	ALBEDO = col.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.05;
}
