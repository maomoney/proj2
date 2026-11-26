extends Node

var should_load_save := false

# In-memory state passed between scenes (not saved to disk automatically)
var hand_cards: Array[String] = []
var gold := 200
var science := 200
var techs_researched: Array[String] = []
const SAVE_PATH := "user://save.json"

func save_game(p_cards: Array, p_hand_cards: Array[String], p_gold: int, p_science: int = 0) -> void:
	var data := {
		"gold":       p_gold,
		"science":    p_science,
		"hand_cards": p_hand_cards,
		"cards":      [],
	}
	for card in p_cards:
		data["cards"].append({"x": card.position.x, "y": card.position.y, "card_id": card.card_id})
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	var raw = json.get_data()
	var card_states: Array = []
	for c in raw.get("cards", []):
		card_states.append({"position": Vector2(c["x"], c["y"]), "card_id": c.get("card_id", "")})
	return {
		"gold":       int(raw.get("gold", 10)),
		"science":    int(raw.get("science", 0)),
		"hand_cards": raw.get("hand_cards", []),
		"cards":      card_states,
	}

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
