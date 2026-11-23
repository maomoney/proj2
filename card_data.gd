class_name CardData

const UNITS: Dictionary = {
	"clubman": {
		"name":        "Clubman",
		"description": "Stone age melee unit",
		"cost":        2,
	},
	"archer": {
		"name":        "Archer",
		"description": "Stone age ranged unit",
		"cost":        3,
	},
}

const BUILDINGS: Dictionary = {
	"farm": {
		"name":        "Farm",
		"description": "Produces food",
		"cost":        4,
	},
}

const TECHS: Dictionary = {
	"archery": {
		"name":        "Archery",
		"description": "Add Archers to shop",
		"cost":        5,
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
