uniform sampler2D wood_atlas : source_color, filter_linear, repeat_disable;
uniform vec4 rough_region = vec4(0.0241, 0.417, 0.9544, 0.1963);
uniform vec4 smooth_region = vec4(0.0241, 0.6836, 0.9544, 0.1934);
uniform vec4 lane_progress = vec4(0.0);
uniform float cut_progress : hint_range(0.0, 1.0) = 0.0;
uniform bool polished = false;
uniform bool inspection = false;
vec4 timber(vec2 uv) {
	// Use a clear-grained strip for inspection; every structural defect is authored by the saved seed.
	vec2 rough_uv = inspection ? vec2(0.43 + uv.x * 0.22, uv.y) : uv;
	vec4 rough = texture(wood_atlas, rough_region.xy + rough_uv * rough_region.zw);
	vec4 smooth_wood = texture(wood_atlas, smooth_region.xy + uv * smooth_region.zw);
	int lane = int(clamp(floor(uv.y * 4.0), 0.0, 3.0));
	float amount = lane_progress[lane];
	float finish = polished ? 1.0 : 1.0 - smoothstep(amount - 0.008, amount + 0.008, uv.x / 0.8);
	vec4 result = mix(rough * vec4(0.83, 0.79, 0.72, 1.0), smooth_wood, finish);
	result.rgb += vec3(0.07, 0.045, 0.018) * finish * pow(max(0.0, 1.0 - abs(uv.y - 0.22) * 4.0), 6.0);
	float seam = (1.0 - smoothstep(0.002, 0.006, abs(uv.x - 0.8))) * step(uv.y, cut_progress);
	result.rgb = mix(result.rgb, vec3(0.10, 0.04, 0.015), seam * 0.9);
	if (cut_progress >= 0.999 && uv.x > 0.8) { result.a = 0.0; }
	return result;
}
