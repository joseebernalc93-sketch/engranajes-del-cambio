shader_type canvas_item;

uniform float wheel_angle = 0.0;

vec2 rotate_spokes(
	vec2 pixel,
	vec2 center,
	float inner_radius,
	float outer_radius,
	float axle_band,
	float angle,
	vec2 sample_pixel
) {
	vec2 offset = pixel - center;
	float radius = length(offset);
	if (radius < inner_radius || radius > outer_radius || abs(offset.y) < axle_band) {
		return sample_pixel;
	}
	float cosine = cos(angle);
	float sine = sin(angle);
	mat2 rotation = mat2(vec2(cosine, -sine), vec2(sine, cosine));
	vec2 rotated_pixel = center + rotation * offset;
	if (abs(rotated_pixel.y - center.y) < axle_band) {
		return sample_pixel;
	}
	return rotated_pixel;
}

void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	vec2 sample_pixel = pixel;

	// Rotate only the spokes. Rims, hubs and connecting rods stay clean and fixed.
	sample_pixel = rotate_spokes(pixel, vec2(158.0, 489.0), 11.0, 29.0, 7.0, wheel_angle, sample_pixel);
	sample_pixel = rotate_spokes(pixel, vec2(250.0, 489.0), 11.0, 29.0, 7.0, wheel_angle, sample_pixel);
	sample_pixel = rotate_spokes(pixel, vec2(387.0, 452.0), 22.0, 51.0, 12.0, wheel_angle, sample_pixel);
	sample_pixel = rotate_spokes(pixel, vec2(541.0, 450.0), 22.0, 51.0, 12.0, wheel_angle, sample_pixel);
	sample_pixel = rotate_spokes(pixel, vec2(707.0, 487.0), 12.0, 31.0, 8.0, wheel_angle, sample_pixel);
	sample_pixel = rotate_spokes(pixel, vec2(815.0, 487.0), 12.0, 31.0, 8.0, wheel_angle, sample_pixel);
	sample_pixel = rotate_spokes(pixel, vec2(908.0, 487.0), 12.0, 31.0, 8.0, wheel_angle, sample_pixel);
	sample_pixel = rotate_spokes(pixel, vec2(1093.0, 485.0), 12.0, 31.0, 8.0, wheel_angle, sample_pixel);
	sample_pixel = rotate_spokes(pixel, vec2(1200.0, 485.0), 12.0, 31.0, 8.0, wheel_angle, sample_pixel);
	sample_pixel = rotate_spokes(pixel, vec2(1385.0, 485.0), 12.0, 31.0, 8.0, wheel_angle, sample_pixel);
	sample_pixel = rotate_spokes(pixel, vec2(1487.0, 485.0), 12.0, 31.0, 8.0, wheel_angle, sample_pixel);
	sample_pixel = rotate_spokes(pixel, vec2(1688.0, 485.0), 12.0, 31.0, 8.0, wheel_angle, sample_pixel);
	sample_pixel = rotate_spokes(pixel, vec2(1787.0, 485.0), 12.0, 31.0, 8.0, wheel_angle, sample_pixel);
	sample_pixel = rotate_spokes(pixel, vec2(1970.0, 485.0), 12.0, 31.0, 8.0, wheel_angle, sample_pixel);
	sample_pixel = rotate_spokes(pixel, vec2(2068.0, 485.0), 12.0, 31.0, 8.0, wheel_angle, sample_pixel);

	COLOR = texture(TEXTURE, sample_pixel * TEXTURE_PIXEL_SIZE) * COLOR;
}
