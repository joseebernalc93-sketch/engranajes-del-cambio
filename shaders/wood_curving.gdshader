shader_type canvas_item;
#include "res://shaders/wood_surface_common.gdshaderinc"
uniform float deflection = 0.0;
void vertex() {
	float supported_x = clamp(UV.x / 0.8, 0.0, 1.0);
	VERTEX.y += deflection * 4.0 * supported_x * (1.0 - supported_x);
}
void fragment() { COLOR = timber(UV); }
