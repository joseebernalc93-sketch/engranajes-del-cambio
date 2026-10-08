shader_type canvas_item;
uniform float methane : hint_range(0.0, 1.0) = 0.0;
uniform float motion_time = 0.0;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float flicker = 0.92 + 0.08 * sin(motion_time * 11.0 + UV.y * 7.0);
	float flame = smoothstep(0.46, 0.0, length(uv * vec2(1.5, 0.8))) * flicker;
	vec3 tint = mix(vec3(1.0, 0.59, 0.14), vec3(0.37, 0.73, 1.0), methane);
	COLOR = vec4(tint, flame * 0.8);
}
