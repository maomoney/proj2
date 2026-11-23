extends Node2D

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const CARD_SCRIPT := preload("res://card.gd")

var card_count := 5
var cards: Array[Node2D] = []

func _ready() -> void:
	$UI/Modal.hide()
	$UI/SettingsModal.hide()

	var res_dropdown: OptionButton = $UI/SettingsModal/MarginContainer/VBox/TabContainer/Graphics/ResolutionOption
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
		card_count = states.size() if states.size() > 0 else card_count
		_spawn_cards()
		for i in cards.size():
			if i < states.size():
				cards[i].position = states[i]["position"]
				cards[i].is_active = states[i]["active"]
				cards[i].card_id = states[i].get("card_id", cards[i].card_id)
				cards[i].queue_redraw()
	else:
		_spawn_cards()

func _spawn_cards() -> void:
	for card in cards:
		card.queue_free()
	cards.clear()
	for i in card_count:
		var card := Node2D.new()
		card.set_script(CARD_SCRIPT)
		card.name = "Card%d" % i
		add_child(card)
		var card_ids := CardData.CARDS.keys()
		card.card_id = card_ids[randi() % card_ids.size()]
		var card_width := 100.0
		var spacing := 120.0
		var total_span := (card_count - 1) * spacing + card_width
		var start_x := (get_viewport_rect().size.x - total_span) / 2.0
		card.position = Vector2(start_x + i * spacing, 200)
		cards.append(card)

func _on_menu_button_pressed() -> void:
	$UI/Modal.show()

func _on_close_button_pressed() -> void:
	$UI/Modal.hide()

func _on_settings_button_pressed() -> void:
	$UI/Modal.hide()
	$UI/SettingsModal.show()

func _on_settings_close_pressed() -> void:
	$UI/SettingsModal.hide()
	$UI/Modal.show()

func _on_resolution_selected(index: int) -> void:
	var res: Vector2i = RESOLUTIONS[index]
	get_window().size = res
	get_window().move_to_center()

func _on_save_exit_pressed() -> void:
	GameState.save_game(cards)
	get_tree().change_scene_to_file("res://main.tscn")
