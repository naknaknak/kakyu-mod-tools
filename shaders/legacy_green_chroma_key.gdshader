shader_type canvas_item;

uniform vec3 chroma_key : source_color = vec3(0.0, 1.0, 0.0);
uniform float soft_min = 0.12;
uniform float soft_max = 0.34;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float key_level = dot(source.rgb, chroma_key);
	float competing_level = max(
		dot(source.rgb, chroma_key.brg),
		dot(source.rgb, chroma_key.gbr)
	);
	float key_excess = key_level - competing_level;
	float key_strength = smoothstep(0.30, 0.72, key_level);
	float key_amount = smoothstep(soft_min, soft_max, key_excess) * key_strength;
	COLOR = vec4(source.rgb, source.a * (1.0 - key_amount));
}
