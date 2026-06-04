shader_type canvas_item;
// DISSOLVE — burn a sprite away (or in) using a noise texture, with a glowing edge.
// Animate `dissolve` from 0.0 (fully visible) to 1.0 (gone). Reverse to materialise.
//
// Setup: assign a NoiseTexture2D to `noise_tex` (a FastNoiseLite works perfectly).
//
// Params:
//   noise_tex  : the dissolve pattern (NoiseTexture2D)
//   dissolve   : 0 = visible, 1 = invisible
//   edge_width : thickness of the glowing burn edge
//   edge_color : colour of the burn edge (orange/cyan look great)

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.3) = 0.06;
uniform vec4 edge_color : source_color = vec4(1.0, 0.55, 0.1, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float n = texture(noise_tex, UV).r;

	if (n < dissolve) {
		discard;
	}

	// Glowing edge just past the dissolve threshold.
	float edge = 1.0 - smoothstep(dissolve, dissolve + edge_width, n);
	vec3 col = mix(tex.rgb, edge_color.rgb, edge);
	COLOR = vec4(col, tex.a);
}
