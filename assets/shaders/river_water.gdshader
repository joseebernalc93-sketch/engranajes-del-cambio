shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	float drift = sin(uv.y * 34.0 + TIME * 2.2) * 0.0025;
	drift += sin(uv.y * 71.0 - TIME * 1.35) * 0.0012;
	uv.x = clamp(uv.x + drift, 0.003, 0.997);

	vec4 water = texture(TEXTURE, uv);
	float shimmer = sin(uv.x * 48.0 + uv.y * 19.0 + TIME * 2.7) * 0.5 + 0.5;
	water.rgb += vec3(0.015, 0.035, 0.045) * shimmer;
	COLOR = water;
}
