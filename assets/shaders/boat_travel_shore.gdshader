shader_type canvas_item;

void fragment() {
	vec4 shore = texture(TEXTURE, UV);
	// Original shore detail stays in place while its blue water reveals the moving river.
	float blue = shore.b - max(shore.r, shore.g * 0.97);
	float water = smoothstep(0.07, 0.20, blue);
	shore.a *= 1.0 - water;
	COLOR = shore;
}
