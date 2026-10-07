shader_type canvas_item;

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float blue = original.b - max(original.r, original.g * 0.97);
	float water_mask = smoothstep(0.08, 0.22, blue);
	vec2 drift = vec2(sin(UV.y * 62.0 + TIME * 1.1) * 0.0018, sin(UV.x * 45.0 - TIME * 0.9) * 0.0009);
	vec4 moving = texture(TEXTURE, clamp(UV + drift * water_mask, vec2(0.001), vec2(0.999)));
	float moving_water = smoothstep(0.08, 0.22, moving.b - max(moving.r, moving.g * 0.97));
	vec4 color = mix(original, moving, water_mask * moving_water);
	color.rgb += vec3(0.004, 0.012, 0.018) * water_mask * (sin(UV.x * 70.0 + TIME * 1.6) * 0.5 + 0.5);
	COLOR = color;
}
