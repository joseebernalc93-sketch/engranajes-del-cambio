shader_type canvas_item;

// Only spokes rotate; the carriage, rims, bearings and screw remain rigid.
uniform float travel_angle = 0.0;
varying vec4 item_modulate;

void vertex() {
	item_modulate = COLOR;
}

vec2 turn_wheel(vec2 pixel, vec2 center) {
	vec2 offset = pixel - center;
	float distance_to_axle = length(offset);
	if (distance_to_axle > 112.0 || distance_to_axle < 43.0) {
		return pixel;
	}
	float c = cos(travel_angle);
	float s = sin(travel_angle);
	return center + mat2(vec2(c, -s), vec2(s, c)) * offset;
}

void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	pixel = turn_wheel(pixel, vec2(350.0, 817.0));
	pixel = turn_wheel(pixel, vec2(1220.0, 817.0));
	COLOR = item_modulate * texture(TEXTURE, pixel * TEXTURE_PIXEL_SIZE);
}
