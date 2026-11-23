extends Node

var should_load_save := false
const SAVE_PATH := "user://save.json"

func save_game(cards: Array) -> void:
	var data := {"cards": []}
	for card in cards:
		data["cards"].append({"x": card.position.x, "y": card.position.y, "active": card.is_active, "card_id": card.card_id})
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

func load_game() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return []
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	var data = json.get_data()
	var states: Array = []
	for c in data["cards"]:
		states.append({"position": Vector2(c["x"], c["y"]), "active": c["active"], "card_id": c.get("card_id", "")})
	return states

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
