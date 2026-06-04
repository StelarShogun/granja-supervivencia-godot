// Low poly animated water for the farm map. Vertex sine waves driven by TIME,
// flat translucent color. No external textures or screen/depth reads, so it is
// compatible everywhere and stays cheap and stylized.

shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.12, 0.45, 0.75, 0.62);
uniform float wave_strength = 0.08;
uniform float wave_speed = 1.2;
uniform float wave_scale = 0.20;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.35;

void vertex() {
	float a = sin((VERTEX.x * wave_scale) + (TIME * wave_speed));
	float b = cos((VERTEX.z * wave_scale * 1.3) + (TIME * wave_speed * 0.8));
	VERTEX.y += (a + b) * wave_strength;
}

void fragment() {
	ALBEDO = water_color.rgb;
	ALPHA = water_color.a;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
