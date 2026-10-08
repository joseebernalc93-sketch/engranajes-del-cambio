shader_type canvas_item;
uniform float turns = 0.0;
uniform float work_clock = 0.0;
uniform float load_stretch = 0.0;
uniform sampler2D hemp_texture : filter_nearest, repeat_disable;
uniform vec4 braid_region = vec4(0.0, 0.0, 1.0, 1.0);
varying vec4 rope_tint;
void vertex() {
	rope_tint = COLOR;
}
void fragment() {
	// The braid is an illustrated pixel-art texture, rather than a synthetic sine stripe.
	COLOR = texture(hemp_texture, braid_region.xy + UV * braid_region.zw) * rope_tint;
}
