extends Node2D

func _ready() -> void:
	$UI/VBox/LoadButton.disabled = not GameState.has_save()

func _on_start_button_pressed() -> void:
	if GameState.has_save():
		$UI/ConfirmDialog.popup_centered()
	else:
		_start_new_game()

func _on_confirm_dialog_confirmed() -> void:
	_start_new_game()

func _start_new_game() -> void:
	GameState.should_load_save = false
	get_tree().change_scene_to_file("res://shop.tscn")

func _on_load_button_pressed() -> void:
	GameState.should_load_save = true
	get_tree().change_scene_to_file("res://shop.tscn")
