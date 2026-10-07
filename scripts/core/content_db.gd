extends Node

const ITEMS := {
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
		"description": "La cosecha escasa fue procesada en el molino. Su venta aporta 13 monedas: 3 para la diligencia y 10 para el boleto del tren.",
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
		"name": "Cuerda de cáñamo",
		"icon": "res://assets/gba/ui/mill_rope_piece_v1.png",
		"description": "Une las poleas que elevan el grano y regulan partes del mecanismo del molino.",
	},
	"tabla": {
		"name": "Tabla resistente",
		"icon": "res://assets/gba/ui/mill_plank_piece_v1.png",
		"description": "Bruno la aserró y cepilló en la isla. Su superficie recta permite reforzar una unión quebrada del molino.",
	},
}


func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})
