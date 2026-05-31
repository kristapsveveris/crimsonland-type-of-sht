shader_type canvas_item;

// Tints the sprite toward flash_color by `flash` (0..1), preserving alpha.
// Used for hit/death flashes; drive `flash` from a tween (1 -> 0). Each
// character creates its own ShaderMaterial in code so the uniform is per-instance.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = mix(tex.rgb, flash_color.rgb, flash * tex.a);
	COLOR = vec4(rgb, tex.a);
}
