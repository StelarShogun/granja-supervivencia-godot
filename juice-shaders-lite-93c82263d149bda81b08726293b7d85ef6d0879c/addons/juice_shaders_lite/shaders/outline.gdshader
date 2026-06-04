shader_type canvas_item;
// OUTLINE — clean pixel outline around any sprite. Great for selection/hover states.
// NOTE: the sprite's texture needs a few px of transparent padding around it,
// otherwise the outline gets clipped at the texture border. (Import > set margins,
// or use a sprite sheet region with padding.)
//
// Params:
//   outline_color : colour of the outline
//   outline_width : thickness in pixels
//   outline_only  : if true, draw ONLY the outline (sprite becomes transparent)

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;
uniform bool outline_only = false;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 ts = TEXTURE_PIXEL_SIZE * outline_width;

	float neighbor = 0.0;
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(ts.x, 0.0)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV - vec2(ts.x, 0.0)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(0.0, ts.y)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV - vec2(0.0, ts.y)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + ts).a);
	neighbor = max(neighbor, texture(TEXTURE, UV - ts).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(ts.x, -ts.y)).a);
	neighbor = max(neighbor, texture(TEXTURE, UV + vec2(-ts.x, ts.y)).a);

	// Outline lives where this pixel is transparent but a neighbour is opaque.
	float outline = min(neighbor, 1.0 - tex.a);

	if (outline_only) {
		COLOR = vec4(outline_color.rgb, outline * outline_color.a);
	} else {
		vec3 col = mix(tex.rgb, outline_color.rgb, outline);
		float alpha = max(tex.a, outline * outline_color.a);
		COLOR = vec4(col, alpha);
	}
}
