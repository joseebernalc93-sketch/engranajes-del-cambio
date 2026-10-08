shader_type canvas_item;
uniform float alignment : hint_range(0.0, 1.0) = 0.0;
uniform float stroke = 0.0;
uniform vec4 fiber_region = vec4(0.0, 0.0, 1.0, 1.0);
void fragment() {
	float x = (UV.x - fiber_region.x) / fiber_region.z;
	float polished = max(alignment, step(x, stroke) * 0.5);
	vec4 hemp = texture(TEXTURE, UV);
	COLOR = vec4(hemp.rgb * mix(0.82, 1.08, polished), hemp.a);
}
