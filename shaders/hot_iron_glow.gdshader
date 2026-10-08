shader_type canvas_item;
uniform float temperature : hint_range(0.0, 1.0) = 0.85;
uniform float motion_time = 0.0;
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 hot = mix(vec3(0.5, 0.08, 0.01), vec3(1.0, 0.83, 0.35), smoothstep(0.3, 1.0, temperature));
	float pulse = 0.96 + 0.04 * sin(motion_time * 2.0);
	COLOR = vec4(mix(base.rgb, hot * pulse, temperature * 0.7), base.a) * COLOR;
}
