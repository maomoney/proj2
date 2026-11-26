extends Panel

signal save_exit_pressed
signal settings_pressed
signal close_pressed

func _ready() -> void:
	hide()

func open() -> void:
	show()

func close() -> void:
	hide()

func _on_save_exit_pressed() -> void:
	save_exit_pressed.emit()

func _on_settings_pressed() -> void:
	settings_pressed.emit()

func _on_close_pressed() -> void:
	close_pressed.emit()
	hide()
