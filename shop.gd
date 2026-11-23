extends Node2D

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const CARD_SCRIPT := preload("res://card.gd")
const REFRESH_COST_INITIAL = 2
const REFRESH_COST_INCREMENT = 1

const CARD_WIDTH := 100.0
const CARD_SPACING    := 120.0

const HAND_OVERLAP  := 20.0
const HAND_SCALE    := 1.5
const HAND_LIFT 	:= 20.0
const HAND_TWEEN_T  := 0.1

const SHOP_SCALE    := 1.2
const SHOP_LIFT 	:= 0
const SHOP_TWEEN_T  := 0.1

var card_count := 5
var cards: Array[Node2D] = []
var hand_cards: Array[String] = []
var hand_nodes: Array[Node2D] = []
var hand_card_hovered: Node2D = null
var gold := 20
var refresh_cost := REFRESH_COST_INITIAL
var _top_layer: CanvasLayer
var _drop_zone: ColorRect
var _sell_drop_zone: ColorRect

func _ready() -> void:
	_top_layer = CanvasLayer.new()
	_top_layer.layer = 10
	add_child(_top_layer)

	var vp := get_viewport_rect().size
	_drop_zone = ColorRect.new()
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_zone.color = Color(0.1, 0.4, 0.9, 0.25)
	_drop_zone.size = Vector2(vp.x, vp.y / 3.0)
	_drop_zone.position = Vector2(0.0, vp.y * 2.0 / 3.0)
	_drop_zone.z_index = -1
	add_child(_drop_zone)
	_drop_zone.hide()

	_sell_drop_zone = ColorRect.new()
	_sell_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_drop_zone.color = Color(0.9, 0.2, 0.1, 0.25)
	_sell_drop_zone.size = Vector2(vp.x, vp.y / 3.0)
	_sell_drop_zone.position = Vector2(0.0, 0.0)
	_sell_drop_zone.z_index = -1
	add_child(_sell_drop_zone)
	_sell_drop_zone.hide()
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
		hand_cards.assign(state.get("hand_cards", hand_cards))
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

	_spawn_hand()
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

	var total_span := (card_count - 1) * CARD_SPACING + CARD_WIDTH
	var start_x    := (get_viewport_rect().size.x - total_span) / 2.0
	for i in card_count:
		var card := Node2D.new()
		card.set_script(CARD_SCRIPT)
		card.name    = "Card%d" % i
		card.card_id = pool[i] if i < pool.size() else all_ids[randi() % all_ids.size()]
		add_child(card)
		card.set_meta("shop_index", i)
		card.position = Vector2(start_x + i * CARD_SPACING, 100)
		card.purchased.connect(_on_card_purchased.bind(card))
		_connect_shop_hover(card)
		cards.append(card)

func _spawn_hand() -> void:
	for n in hand_nodes:
		n.queue_free()
	hand_nodes.clear()
	hand_card_hovered = null
	if hand_cards.is_empty():
		return

	var card_width  := 100.0
	var step        := card_width - HAND_OVERLAP
	var total_span  := step * (hand_cards.size() - 1) + card_width
	var vp          := get_viewport_rect().size
	var start_x     := (vp.x - total_span) / 2.0
	var base_y      := vp.y * 2.0 / 3.0 + 20.0  # top of bottom third

	for i in hand_cards.size():
		var card := Node2D.new()
		card.set_script(CARD_SCRIPT)
		card.name    = "Hand%d" % i
		card.card_id = hand_cards[i] as String
		add_child(card)
		card.z_index = i
		card.set_meta("hand_index", i)
		card.position = Vector2(start_x + i * step, base_y)
		_connect_hand_hover(card, i)
		hand_nodes.append(card)

func _shop_card_position(index: int) -> Vector2:
	var n          := cards.size()
	var total_span := (n - 1) * CARD_SPACING + CARD_WIDTH
	var start_x    := (get_viewport_rect().size.x - total_span) / 2.0
	return Vector2(start_x + index * CARD_SPACING, 100)

func _hand_card_position(index: int) -> Vector2:
	var n          := hand_cards.size()
	var card_width := 100.0
	var step       := card_width - HAND_OVERLAP
	var total_span := step * (n - 1) + card_width
	var vp         := get_viewport_rect().size
	var start_x    := (vp.x - total_span) / 2.0
	var base_y     := vp.y * 2.0 / 3.0 + 20.0
	return Vector2(start_x + index * step, base_y)

func _connect_shop_hover(card: Node2D) -> void:
	var card_w: float = card.card_size.x
	var card_h: float = card.card_size.y
	card.drag_started.connect(func() -> void:
		get_tree().create_timer(0.2).timeout.connect(func() -> void:
			if is_instance_valid(card) and card.dragging:
				_drop_zone.show()
		)
	)
	card.drag_ended.connect(func() -> void:
		_drop_zone.hide()
		var drop_y: float = card.global_position.y + card_h / 2.0
		if drop_y >= get_viewport_rect().size.y * 2.0 / 3.0:
			card.purchased.emit()
		else:
			var origin := _shop_card_position(card.get_meta("shop_index") as int)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(card, "scale",    Vector2.ONE, SHOP_TWEEN_T)
			tw.tween_property(card, "position", origin,      SHOP_TWEEN_T)
	)
	card.mouse_entered.connect(func() -> void:
		_lift_card(card)
		var base  := _shop_card_position(card.get_meta("shop_index") as int)
		var offset := Vector2(card_w / 2.0 * (1.0 - SHOP_SCALE),
							  card_h / 2.0 * (1.0 - SHOP_SCALE) - SHOP_LIFT)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "scale",    Vector2(SHOP_SCALE, SHOP_SCALE), SHOP_TWEEN_T)
		tw.tween_property(card, "position", base + offset,                   SHOP_TWEEN_T)
	)
	card.mouse_exited.connect(func() -> void:
		_drop_card(card)
		var base := _shop_card_position(card.get_meta("shop_index") as int)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "scale",    Vector2.ONE, SHOP_TWEEN_T)
		tw.tween_property(card, "position", base,        SHOP_TWEEN_T)
	)

func _connect_hand_hover(card: Node2D, base_z: int) -> void:
	card.set_meta("base_z", base_z)
	var card_w: float = card.card_size.x
	var card_h: float = card.card_size.y
	card.drag_started.connect(func() -> void:
		get_tree().create_timer(0.2).timeout.connect(func() -> void:
			if is_instance_valid(card) and card.dragging:
				_sell_drop_zone.show()
		)
	)
	card.drag_ended.connect(func() -> void:
		_sell_drop_zone.hide()
		var drop_y: float = card.global_position.y + card_h / 2.0
		if drop_y <= get_viewport_rect().size.y / 3.0:
			_sell_hand_card(card)
		else:
			var origin := _hand_card_position(card.get_meta("hand_index") as int)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(card, "scale",    Vector2.ONE, HAND_TWEEN_T)
			tw.tween_property(card, "position", origin,      HAND_TWEEN_T)
	)
	card.mouse_entered.connect(func() -> void:
		if hand_card_hovered == card:
			return
		if hand_card_hovered != null:
			_unhover_hand_card(hand_card_hovered)
		hand_card_hovered = card
		_lift_card(card)
		var base := _hand_card_position(card.get_meta("hand_index") as int)
		var offset := Vector2(card_w / 2.0 * (1.0 - HAND_SCALE),
							  card_h       * (1.0 - HAND_SCALE) - HAND_LIFT)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "scale",    Vector2(HAND_SCALE, HAND_SCALE), HAND_TWEEN_T)
		tw.tween_property(card, "position", base + offset,                   HAND_TWEEN_T)
	)
	card.mouse_exited.connect(func() -> void:
		if hand_card_hovered == card:
			hand_card_hovered = null
		_unhover_hand_card(card)
	)

func _lift_card(card: Node2D) -> void:
	var global := card.global_position
	card.reparent(_top_layer)
	card.global_position = global

func _drop_card(card: Node2D) -> void:
	if card.get_parent() != self:
		var global := card.global_position
		card.reparent(self)
		card.global_position = global

func _unhover_hand_card(card: Node2D) -> void:
	_drop_card(card)
	var base := _hand_card_position(card.get_meta("hand_index") as int)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "scale",    Vector2.ONE, HAND_TWEEN_T)
	tw.tween_property(card, "position", base,        HAND_TWEEN_T)

func _reindex_shop_cards() -> void:
	var n := cards.size()
	var total_span := (n - 1) * CARD_SPACING + CARD_WIDTH
	var start_x    := (get_viewport_rect().size.x - total_span) / 2.0
	for i in n:
		cards[i].set_meta("shop_index", i)
		var target := Vector2(start_x + i * CARD_SPACING, 100)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(cards[i], "position", target, SHOP_TWEEN_T)
		tw.tween_property(cards[i], "scale",    Vector2.ONE, SHOP_TWEEN_T)

func _sell_hand_card(card: Node2D) -> void:
	var data: Dictionary = CardData.get_all().get(card.card_id, {})
	var refund: int = data.get("cost", 0) / 2
	gold += refund
	var idx: int = card.get_meta("hand_index") as int
	hand_cards.remove_at(idx)
	hand_nodes.erase(card)
	if hand_card_hovered == card:
		hand_card_hovered = null
	card.queue_free()
	# Reindex remaining hand nodes.
	for i in hand_nodes.size():
		hand_nodes[i].set_meta("hand_index", i)
		hand_nodes[i].z_index = i
		var target := _hand_card_position(i)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(hand_nodes[i], "position", target,      HAND_TWEEN_T)
		tw.tween_property(hand_nodes[i], "scale",    Vector2.ONE, HAND_TWEEN_T)
	_update_gold_label()

func _update_gold_label() -> void:
	$UI/GoldLabel.text = "Gold: %d" % gold
	$UI/TitleRow/RefreshButton.text = "Refresh (%dg)" % refresh_cost

func _on_card_purchased(card: Node2D) -> void:
	var data: Dictionary = CardData.get_all().get(card.card_id, {})
	var cost: int = data.get("cost", 0)
	if gold < cost:
		_drop_card(card)
		var origin := _shop_card_position(card.get_meta("shop_index") as int)
		var tw := create_tween()
		tw.tween_property(card, "modulate", Color.RED,   SHOP_TWEEN_T)
		tw.tween_property(card, "modulate", Color.WHITE, SHOP_TWEEN_T * 2)
		tw.set_parallel(true)
		tw.tween_property(card, "scale",    Vector2.ONE, SHOP_TWEEN_T * 2)
		tw.tween_property(card, "position", origin,      SHOP_TWEEN_T * 2)
		return
	gold -= cost
	hand_cards.append(card.card_id)
	cards.erase(card)
	card.queue_free()
	_reindex_shop_cards()
	_spawn_hand()
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
