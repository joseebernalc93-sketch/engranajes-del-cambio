shader_type canvas_item;
render_mode unshaded;
uniform float motion_time = 0.0;
uniform float intensity = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void fragment() {
	vec2 uv = floor(UV * vec2(90.0, 58.0)) / vec2(90.0, 58.0);
	float turbulent = noise(vec2(uv.x * 9.0, uv.y * 4.0 + motion_time * 2.2));
	float tips = noise(vec2(uv.x * 19.0, uv.y * 8.0 + motion_time * 3.5));
	float body = uv.y - 0.30 + turbulent * 0.42 + tips * 0.12;
	body *= smoothstep(0.0, 0.12, uv.x) * (1.0 - smoothstep(0.88, 1.0, uv.x));
	float alpha = smoothstep(0.5, 0.57, body) * clamp(intensity * 3.0, 0.0, 1.0);
	vec3 flame = mix(vec3(0.8, 0.19, 0.035), vec3(1.0, 0.71, 0.18), smoothstep(0.55, 0.85, body));
	flame = mix(flame, vec3(1.0, 0.91, 0.56), smoothstep(1.0, 1.2, body));
	COLOR = vec4(flame, alpha * 0.9);
}
