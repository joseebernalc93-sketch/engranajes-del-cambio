shader_type canvas_item;
uniform float pressure : hint_range(0.0, 1.0) = 0.5;
uniform float motion_time = 0.0;
void fragment() {
	vec2 uv = UV;
	uv.x += sin(uv.y * 14.0 - motion_time * 3.0) * pressure * 0.025;
	vec4 puff = texture(TEXTURE, uv);
	COLOR = vec4(puff.rgb, puff.a * pressure * 0.6) * COLOR;
}
