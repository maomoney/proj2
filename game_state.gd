extends Node

var should_load_save := false
const SAVE_PATH := "user://save.json"

func save_game(boxes: Array) -> void:
	var data := {"boxes": []}
	for box in boxes:
		data["boxes"].append({"x": box.position.x, "y": box.position.y, "active": box.is_active})
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
	for b in data["boxes"]:
		states.append({"position": Vector2(b["x"], b["y"]), "active": b["active"]})
	return states

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
