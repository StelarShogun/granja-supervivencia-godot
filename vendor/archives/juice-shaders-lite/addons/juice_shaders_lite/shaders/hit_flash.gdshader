shader_type canvas_item;
// HIT FLASH — flash a sprite toward a solid colour when it takes damage.
// Drive `flash_amount` from code (a Tween from 1.0 -> 0.0 works great).
//
// Params:
//   flash_color  : the colour to flash toward (white = classic, red = aggressive)
//   flash_amount : 0.0 = normal sprite, 1.0 = fully the flash colour
//
// GDScript (see docs/USAGE.md):
//   var mat := sprite.material as ShaderMaterial
//   mat.set_shader_parameter("flash_amount", 1.0)
//   create_tween().tween_property(mat, "shader_parameter/flash_amount", 0.0, 0.15)

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 flashed = mix(tex.rgb, flash_color.rgb, flash_amount);
	COLOR = vec4(flashed, tex.a);
}
