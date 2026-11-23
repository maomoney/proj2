extends Node2D

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const CARD_SCRIPT := preload("res://card.gd")
const REFRESH_COST_INITIAL = 2
const REFRESH_COST_INCREMENT = 1

var card_count := 5
var cards: Array[Node2D] = []
var hand_cards: Array[String] = []
var gold := 20
var refresh_cost := REFRESH_COST_INITIAL

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
		var state := GameState.load_game()
		gold = state.get("gold", gold)
		hand_cards = state.get("hand_cards", hand_cards)
		var card_states: Array = state.get("cards", [])
		card_count = card_states.size() if card_states.size() > 0 else card_count
		_spawn_cards()
		for i in cards.size():
			if i < card_states.size():
				cards[i].position = card_states[i]["position"]
				cards[i].card_id  = card_states[i].get("card_id", cards[i].card_id)
				cards[i].queue_redraw()
	else:
		_spawn_cards()

	_update_gold_label()

func _spawn_cards() -> void:
	for card in cards:
		card.queue_free()
	cards.clear()

	var all_ids    := CardData.get_all().keys()
	var building_ids := CardData.BUILDINGS.keys()
	var tech_ids     := CardData.TECHS.keys()

	# Build the pool: shuffle all ids, pick card_count with constraints.
	# Constraint 1: at least 1 building.
	# Constraint 2: no duplicate techs.
	var pool: Array[String] = []
	# Reserve one slot for a guaranteed building.
	pool.append(building_ids[randi() % building_ids.size()])
	# Fill remaining slots randomly, rejecting tech duplicates.
	var used_techs: Dictionary = {}
	var remaining := card_count - 1
	var attempts  := 0
	while pool.size() < card_count and attempts < card_count * 20:
		attempts += 1
		var id: String = all_ids[randi() % all_ids.size()]
		if CardData.get_type(id) == "Tech" and used_techs.has(id):
			continue
		if CardData.get_type(id) == "Tech":
			used_techs[id] = true
		pool.append(id)
	# Shuffle so the building isn't always first.
	pool.shuffle()

	var card_width := 100.0
	var spacing    := 120.0
	var total_span := (card_count - 1) * spacing + card_width
	var start_x    := (get_viewport_rect().size.x - total_span) / 2.0
	for i in card_count:
		var card := Node2D.new()
		card.set_script(CARD_SCRIPT)
		card.name    = "Card%d" % i
		card.card_id = pool[i] if i < pool.size() else all_ids[randi() % all_ids.size()]
		add_child(card)
		card.position = Vector2(start_x + i * spacing, 100)
		card.purchased.connect(_on_card_purchased.bind(card))
		cards.append(card)

func _update_gold_label() -> void:
	$UI/GoldLabel.text = "Gold: %d" % gold
	$UI/TitleRow/RefreshButton.text = "Refresh (%dg)" % refresh_cost

func _on_card_purchased(card: Node2D) -> void:
	var data: Dictionary = CardData.get_all().get(card.card_id, {})
	var cost: int = data.get("cost", 0)
	if gold < cost:
		return
	gold -= cost
	hand_cards.append(card.card_id)
	cards.erase(card)
	card.queue_free()
	_update_gold_label()

func _on_refresh_pressed() -> void:
	if gold < refresh_cost:
		return
	gold -= refresh_cost
	refresh_cost += REFRESH_COST_INCREMENT
	_spawn_cards()
	_update_gold_label()

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
	GameState.save_game(cards, hand_cards, gold)
	get_tree().change_scene_to_file("res://main.tscn")
