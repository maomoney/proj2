extends Node2D

var _hand: HandManager
var _top_layer: CanvasLayer

func _ready() -> void:
	_top_layer = CanvasLayer.new()
	_top_layer.layer = 10
	add_child(_top_layer)

	_hand = HandManager.new()
	_hand.show_sell_value = false
	_hand.setup(self, _top_layer)
	_hand.hand_cards.assign(GameState.hand_cards)
	_hand.spawn()

	$UI/GoldRow/GoldLabel.text    = str(GameState.gold)
	$UI/GoldRow/ScienceLabel.text = str(GameState.science)

	const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
	var res_dropdown: OptionButton = $UI/SettingsModal/MarginContainer/VBox/TabContainer/Graphics/ResolutionOption
	for r in RESOLUTIONS:
		res_dropdown.add_item("%d × %d" % [r.x, r.y])
	var current := DisplayServer.window_get_size()
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i] == current:
			res_dropdown.selected = i
			break

func _process(_delta: float) -> void:
	_hand.process_drag()

func _on_shop_button_pressed() -> void:
	GameState.hand_cards.assign(_hand.hand_cards)
	get_tree().change_scene_to_file("res://shop.tscn")

func _on_menu_button_pressed() -> void:
	$UI/Modal.open()

func _on_close_button_pressed() -> void:
	$UI/Modal.close()

func _on_settings_button_pressed() -> void:
	$UI/Modal.close()
	$UI/SettingsModal.show()

func _on_settings_close_pressed() -> void:
	$UI/SettingsModal.hide()
	$UI/Modal.open()

func _on_resolution_selected(index: int) -> void:
	const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
	var res: Vector2i = RESOLUTIONS[index]
	get_window().size = res
	get_window().move_to_center()

func _on_save_exit_pressed() -> void:
	GameState.hand_cards.assign(_hand.hand_cards)
	GameState.save_game([], _hand.hand_cards, GameState.gold, GameState.science)
	get_tree().change_scene_to_file("res://main.tscn")
