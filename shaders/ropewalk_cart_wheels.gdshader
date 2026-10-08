shader_type canvas_item;
uniform float wheel_angle = 0.0;
void fragment() {
	vec2 uv = UV;
	// Rotate only the two existing wheel faces, preserving their iron rims and the chassis.
	for (int wheel = 0; wheel < 2; wheel++) {
		vec2 center = wheel == 0 ? vec2(0.251, 0.791) : vec2(0.798, 0.791);
		vec2 radius = vec2(0.094, 0.141);
		vec2 offset = (UV - center) / radius;
		if (length(offset) < 1.0) {
			float c = cos(wheel_angle);
			float s = sin(wheel_angle);
			uv = center + mat2(vec2(c, -s), vec2(s, c)) * offset * radius;
		}
	}
	COLOR = texture(TEXTURE, uv);
}
