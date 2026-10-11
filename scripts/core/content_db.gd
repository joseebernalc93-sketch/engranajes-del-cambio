extends Node

const ITEMS := {
	"costal_carbon": {"name": "Costal de carbón", "icon": "res://assets/phase2/iron_mission_parts_pixel_v2.png", "description": "Hulla extraída y separada de la piedra. Cada costal contiene seis paladas para alimentar el hogar de la caldera. Caleb permite reponer combustible en el pozo."},
	"hulla": {"name": "Carbón de hulla seleccionado", "icon": "res://assets/phase2/tools_pixel_v1.png", "description": "Hulla cribada por Caleb. Su energía alimenta la caldera; la ventilación del grisú es indispensable en la mina."},
	"biela": {"name": "Biela de hierro forjado", "icon": "res://assets/phase2/foundry_materials_atlas_v1.png", "description": "Barra calentada, forjada, perforada y ajustada en el taller de Cort. Sus dos ojos reciben los pasadores del pistón y el volante. Entrégala a Murdoch para montar la transmisión; los costales alimentan su caldera."},
	"potencia_vapor": {"name": "Transmisión de vapor habilitada", "icon": "res://assets/phase2/tools_pixel_v1.png", "description": "Motor de doble efecto con condensador separado y regulador. Convierte calor en movimiento y lo distribuye mediante correas."},
	"pano_industrial": {"name": "Fardos de paño industrial", "icon": "res://assets/phase2/tools_pixel_v1.png", "description": "Diez fardos tejidos durante un turno fabril. El trabajo coordinado, el suministro de hilo y el mantenimiento sostienen la producción."},
	"herramientas": {
		"name": "Herramientas agrícolas",
		"icon": "res://assets/gba/ui/tools_icon_gba.png",
		"description": "Azada y hoz usadas en el trabajo manual. Mateo puede recuperar su hierro para reforzar una rueda dentada.",
	},
	"trigo": {
		"name": "Puñado de trigo",
		"icon": "res://assets/items/wheat_v2.png",
		"description": "Cosecha escasa de una parcela pequeña. Los cercamientos redujeron el acceso campesino a las tierras comunales.",
	},
	"costal_harina": {
		"name": "Costal de harina",
		"icon": "res://assets/items/flour_sack_v1.png",
		"description": "La cosecha escasa fue procesada en el molino. Su venta aporta 100 monedas: 3 para la diligencia y 10 para el boleto del tren.",
	},
	"boleto": {
		"name": "Boleto de tren",
		"icon": "res://assets/items/train_ticket_v2.png",
		"description": "Pasaje hacia la ciudad industrial. El ferrocarril, impulsado por vapor, aceleró la movilidad de personas y mercancías.",
	},
	"rueda_dentada": {
		"name": "Rueda dentada reforzada",
		"icon": "res://assets/gba/ui/mill_gear_piece_v1.png",
		"description": "Mateo reforzó la rueda con el hierro recuperado de las herramientas. Transmite el giro hacia las piedras del molino.",
	},
	"cuerda": {
		"name": "Soga de transmisión resistente",
		"icon": "res://assets/gba/ui/mill_rope_piece_v1.png",
		"description": "Cáñamo peinado, repartido en tres cabos, torcido, ligado con hilo encerado y ensayado junto a Silas. Une las poleas del molino para transmitir movimiento y elevar el grano.",
	},
	"tabla": {
		"name": "Tabla de soporte de la bancada",
		"icon": "res://assets/gba/ui/mill_plank_piece_v1.png",
		"description": "Seleccionada, trazada, aserrada, cepillada y ensayada junto a Bruno en la isla. Refuerza la bancada que sostiene el mecanismo del molino.",
	},
}


func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

func get_item_icon(item_id: String) -> Texture2D:
	if item_id == "biela": return preload("res://scripts/world/foundry_workshop_art.gd").part(6)
	var item := get_item(item_id)
	var icon_path := str(item.get("icon", ""))
	if icon_path.is_empty(): return null
	var source := load(icon_path) as Texture2D
	if item_id == "costal_carbon":
		var coal := AtlasTexture.new()
		coal.atlas = source
		var coal_cell := source.get_size() / Vector2(4, 2)
		coal.region = Rect2(coal_cell, coal_cell)
		return coal
	var frames := {"hulla": 2, "biela": 6, "potencia_vapor": 9, "pano_industrial": 11}
	if not frames.has(item_id): return source
	var texture := AtlasTexture.new()
	texture.atlas = source
	var cell := Vector2(source.get_width() / 4.0, source.get_height() / 3.0)
	var frame: int = frames[item_id]
	texture.region = Rect2(Vector2(frame % 4, frame / 4) * cell, cell)
	if frame == 6: texture.region = Rect2(cell.x * 2.16, cell.y * 1.06, cell.x * 0.74, cell.y * 0.93)
	return texture
