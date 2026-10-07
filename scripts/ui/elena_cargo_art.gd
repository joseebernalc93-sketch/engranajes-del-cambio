extends RefCounted
## Shared sprites for the cargo, selection cards and keyboard-accessible buttons.

const TEXTURES := {
	"alimentos": preload("res://assets/gba/ui/elena_food_bundle_v3.png"),
	"mantas": preload("res://assets/gba/ui/elena_blankets_v3.png"),
	"herramientas": preload("res://assets/gba/ui/elena_toolbox_v3.png"),
	"retrato": preload("res://assets/gba/ui/elena_family_portrait_v3.png"),
	"olla": preload("res://assets/gba/ui/elena_iron_pot_v3.png"),
	"semillas": preload("res://assets/gba/ui/elena_seed_sack_v3.png"),
}
const SIZES := {
	"alimentos": Vector2(66, 67),
	"mantas": Vector2(75, 53),
	"herramientas": Vector2(70, 76),
	"retrato": Vector2(49, 71),
	"olla": Vector2(64, 65),
	"semillas": Vector2(48, 60),
}
const NAMES := {"alimentos": "ALIMENTOS", "mantas": "MANTAS", "herramientas": "HERRAMIENTAS", "retrato": "RETRATO FAMILIAR", "olla": "OLLA DE HIERRO", "semillas": "SEMILLAS"}
const DETAILS := {"alimentos": "Pan, fruta y raíces", "mantas": "Lana tejida y abrigo", "herramientas": "Madera y hierro forjado", "retrato": "Un recuerdo de familia", "olla": "Hierro gastado por el uso", "semillas": "Reserva para sembrar"}
const REGIONS := {
	"alimentos": Rect2(47, 61, 1169, 1137),
	"mantas": Rect2(19, 165, 1218, 921),
	"herramientas": Rect2(16, 81, 1223, 1077),
	"retrato": Rect2(146, 12, 962, 1200),
	"olla": Rect2(90, 31, 1089, 1179),
	"semillas": Rect2(85, 49, 1085, 1154),
}


static func icon(id: String) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = TEXTURES[id]
	result.region = REGIONS[id]
	return result
