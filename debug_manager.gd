extends Node

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			var scene := get_tree().current_scene
			if scene and scene.has_method("quick_save"):
				scene.quick_save()
			GameState.should_load_save = true
			get_tree().reload_current_scene()
