shader_type canvas_item;
render_mode unshaded;
uniform sampler2D workshop_screen : hint_screen_texture, repeat_disable, filter_linear;
uniform float magnification : hint_range(1.0, 3.0) = 1.8;
uniform vec2 lens_screen_size = vec2(0.1);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 offset = (UV - vec2(0.5)) * lens_screen_size;
	vec2 sample_uv = SCREEN_UV - offset + offset / magnification * (1.0 + r * r * 0.12);
	vec4 wood = texture(workshop_screen, sample_uv);
	wood.rgb *= vec3(1.12, 1.04, 0.85);
	float glass = 1.0 - smoothstep(0.88, 0.91, r);
	float ring = smoothstep(0.88, 0.91, r) * (1.0 - smoothstep(0.98, 1.0, r));
	vec3 brass = mix(vec3(0.25, 0.14, 0.04), vec3(0.93, 0.73, 0.36), clamp(0.5 - p.y * 0.8, 0.0, 1.0));
	COLOR = vec4(mix(wood.rgb, brass, ring), max(glass, ring));
}
