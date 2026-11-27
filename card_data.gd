class_name CardData

const UNITS: Dictionary = {
	"clubman": {
		"name":        "Clubman",
		"description": "Stone age melee unit",
		"cost":        5,
		"icon_png": 	preload("res://assets/Icons_RPG.png"),  # optional png override
		"icon":    	 	Vector2i(10, 0),
	},
	"bowman": {
		"name":        "Bowman",
		"description": "Stone age ranged unit",
		"cost":        7,
		"requires":	   ["archery"],
		"icon_png": 	preload("res://assets/Icons_RPG.png"),  # optional png override
		"icon":    	 	Vector2i(5, 0),
	},
}

const BUILDINGS: Dictionary = {
	"farm": {
		"name":        "Farm",
		"description": "Produces food",
		"cost":        5,
		"icon_png": 	preload("res://assets/Icons_Food.png"),  # optional png override
		"icon":    	 	Vector2i(1, 0),
	},
	"granary": {
		"name":        "Granary",
		"description": "Adjacent farms +1 yield",
		"cost":        5,
		"requires":	   ["pottery"],
		"icon_png": 	preload("res://assets/Icons_Map_Markers.png"),  # optional png override
		"icon":    	 	Vector2i(10, 3),
	},
	"library": {
		"name":        "Library",
		"description": "Produces science",
		"cost":        8,
		"requires":	   ["writing"],
		"icon_png": 	preload("res://assets/Icons_Map_Markers.png"),  # optional png override
		"icon":    	 	Vector2i(3, 0),
	}
}

const TECHS: Dictionary = {
	"archery": {
		"name":        "Archery",
		"description": "Add Bowman to shop",
		"cost":        10,
	},
	"pottery": {
		"name":        "Pottery",
		"description": "Add Granary to shop",
		"cost":        10,
	},
	"writing": {
		"name":        "Writing",
		"description": "Add Library to shop",
		"cost":        20,
		"requires":	   ["pottery"]
	},
}

static func get_all() -> Dictionary:
	var all := {}
	all.merge(UNITS)
	all.merge(BUILDINGS)
	all.merge(TECHS)
	return all

static func get_type(card_id: String) -> String:
	if UNITS.has(card_id):     return "Unit"
	if BUILDINGS.has(card_id): return "Building"
	if TECHS.has(card_id):     return "Tech"
	return ""
