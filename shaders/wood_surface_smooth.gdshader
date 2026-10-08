shader_type canvas_item;
#include "res://shaders/wood_surface_common.gdshaderinc"
void fragment() { COLOR = timber(UV); }
