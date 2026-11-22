extends Node2D

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]

func _ready() -> void:
	$UI/Modal.hide()
	$UI/SettingsModal.hide()
	var res_dropdown: OptionButton = $UI/SettingsModal/MarginContainer/VBox/ResolutionOption
	for r in RESOLUTIONS:
		res_dropdown.add_item("%d × %d" % [r.x, r.y])
	var current := DisplayServer.window_get_size()
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i] == current:
			res_dropdown.selected = i
			break
	if GameState.should_load_save:
		GameState.should_load_save = false
		var states := GameState.load_game()
		var boxes := [$Box1, $Box2, $Box3]
		for i in boxes.size():
			if i < states.size():
				boxes[i].position = states[i]["position"]
				boxes[i].is_active = states[i]["active"]
				boxes[i].queue_redraw()

func _on_menu_button_pressed() -> void:
	$UI/Modal.show()

func _on_close_button_pressed() -> void:
	$UI/Modal.hide()

func _on_graphics_button_pressed() -> void:
	$UI/SettingsModal.show()

func _on_settings_close_pressed() -> void:
	$UI/SettingsModal.hide()

func _on_resolution_selected(index: int) -> void:
	var res: Vector2i = RESOLUTIONS[index]
	get_window().size = res
	get_window().move_to_center()

func _on_save_exit_pressed() -> void:
	GameState.save_game([$Box1, $Box2, $Box3])
	get_tree().change_scene_to_file("res://main.tscn")
