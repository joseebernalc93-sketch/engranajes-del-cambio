shader_type canvas_item;

void fragment() {
	// Sample only open water from the original river art, at a natural visual scale.
	vec2 tile = UV * vec2(6.8, 4.4);
	tile.x += TIME * 0.012 + sin(tile.y * 9.0 + TIME * 1.2) * 0.007;
	tile.y += sin(tile.x * 8.0 - TIME * 0.8) * 0.004;
	vec2 mirrored = 1.0 - abs(mod(tile, 2.0) - 1.0);
	vec2 sample_uv = vec2(mirrored.x, 0.22 + mirrored.y * 0.55);
	vec4 water = texture(TEXTURE, sample_uv);
	float light = sin(UV.x * 36.0 + UV.y * 19.0 + TIME * 0.7) * 0.5 + 0.5;
	water.rgb = mix(water.rgb * vec3(0.86, 0.94, 1.0), water.rgb, light * 0.45 + 0.4);
	COLOR = water;
}
