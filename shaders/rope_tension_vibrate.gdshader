shader_type canvas_item;
uniform float tension = 55.0;
uniform float work_clock = 0.0;
uniform float turns = 5.0;
uniform sampler2D hemp_texture : filter_nearest, repeat_disable;
uniform vec4 braid_region = vec4(0.0, 0.0, 1.0, 1.0);
varying vec4 rope_tint;
void vertex() {
	rope_tint = COLOR;
	float amplitude = clamp((tension - 65.0) / 20.0, 0.0, 1.0) * 3.0;
	VERTEX.y += sin(UV.x * 45.0 + work_clock * 24.0) * amplitude * sin(UV.x * 3.14159);
}
void fragment() {
	COLOR = texture(hemp_texture, braid_region.xy + UV * braid_region.zw) * rope_tint;
}
