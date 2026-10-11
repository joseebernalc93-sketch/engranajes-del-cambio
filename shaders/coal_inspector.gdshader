shader_type canvas_item;
uniform vec2 lamp_center = vec2(0.45, 0.4);
uniform float motion_time = 0.0;
void fragment() {
	vec2 pixel_uv = floor(UV * vec2(576.0, 324.0)) / vec2(576.0, 324.0);
	float distance_to_lamp = length((pixel_uv - lamp_center) * vec2(1.7778, 1.0));
	float pool = 1.0 - smoothstep(0.025, 0.24, distance_to_lamp);
	float flicker = 0.98 + 0.02 * sin(motion_time * 7.0);
	vec4 surface = texture(TEXTURE, UV);
	COLOR = vec4(surface.rgb * (0.64 + pool * 0.42 * flicker) * mix(vec3(0.88, 0.91, 1.0), vec3(1.08, 1.0, 0.85), pool), surface.a);
}
