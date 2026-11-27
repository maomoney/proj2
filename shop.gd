extends Node2D

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const CARD_SCRIPT := preload("res://card.gd")
const REFRESH_COST_INITIAL = 2
const REFRESH_COST_INCREMENT = 1

const CARD_WIDTH := 100.0
const CARD_SPACING    := 106.0

const SHOP_SCALE    := 1.1
const SHOP_LIFT 	:= 0
const SHOP_TWEEN_T  := 0.1
const COST_LABEL_OFFSET_Y := 150.0  # below the card's bottom edge (card height 140)
const COST_LABEL_HEIGHT   := 20.0
const COST_LABEL_WIDTH    := 80.0   # background rect width, centered under the card
const COST_LABEL_BG_COLOR := Color(0.12, 0.12, 0.12, 0.85)
const COST_LABEL_COLOR    := Color(0.949, 0.761, 0.051, 1)
const COIN_TEXTURE        := preload("res://assets/coin.png")
const BEAKER_TEXTURE      := preload("res://assets/beaker.png")
const LABEL_FONT          := preload("res://assets/Kubasta.ttf")
const SCIENCE_LABEL_COLOR := Color(0.4, 0.78, 1.0, 1)

var card_count := 10
var cards: Array[Node2D] = []
var _hand: HandManager
var _shop_card_dragging: Node2D = null
var _shop_card_hovered: Node2D = null
var techs_researched: Array[String] = []
var _shop_hover_preview: Node2D = null
var gold := 200
var science := 200
var _displayed_gold := 0.0
var _displayed_science := 0.0
var _gold_tween: Tween
var _science_tween: Tween
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
	_drop_zone.size = Vector2(vp.x, vp.y / 2.0)
	_drop_zone.position = Vector2(0.0, vp.y / 2.0)
	_drop_zone.z_index = -1
	add_child(_drop_zone)
	_drop_zone.hide()

	_sell_drop_zone = ColorRect.new()
	_sell_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_drop_zone.color = Color(0.9, 0.2, 0.1, 0.25)
	_sell_drop_zone.size = Vector2(vp.x, vp.y / 2.0)
	_sell_drop_zone.position = Vector2(0.0, 0.0)
	_sell_drop_zone.z_index = -1
	add_child(_sell_drop_zone)
	_sell_drop_zone.hide()

	_hand = HandManager.new()
	_hand.setup(self, _top_layer, _sell_drop_zone)
	_hand.sell_requested.connect(_sell_hand_card)

	$UI/Modal.close()
	$UI/SettingsModal.hide()

	var res_dropdown: OptionButton = $UI/SettingsModal/MarginContainer/VBox/TabContainer/Graphics/ResolutionOption
	for r in RESOLUTIONS:
		res_dropdown.add_item("%d × %d" % [r.x, r.y])
	var current := DisplayServer.window_get_size()
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i] == current:
			res_dropdown.selected = i
			break

	# Load from GameState (set by town or save/load)
	gold              = GameState.gold
	science           = GameState.science
	techs_researched.assign(GameState.techs_researched)
	_hand.hand_cards.assign(GameState.hand_cards)

	if GameState.should_load_save:
		GameState.should_load_save = false
		var state := GameState.load_game()
		gold = state.get("gold", gold)
		science = state.get("science", science)
		_hand.hand_cards.assign(state.get("hand_cards", _hand.hand_cards))
		var card_states: Array = state.get("cards", [])
		_spawn_cards(card_states.size() if card_states.size() > 0 else card_count)
		for i in cards.size():
			if i < card_states.size():
				cards[i].position = card_states[i]["position"]
				cards[i].card_id  = card_states[i].get("card_id", cards[i].card_id)
				cards[i].queue_redraw()
				# Cost label was built with the random pool id; update it to match the saved card.
				if cards[i].has_meta("cost_label"):
					var data: Dictionary = CardData.get_all().get(cards[i].card_id, {})
					var saved_is_tech := CardData.get_type(cards[i].card_id) == "Tech"
					var lbl := cards[i].get_meta("cost_label") as Label
					lbl.text = "%d" % int(data.get("cost", 0))
					lbl.add_theme_color_override("font_color", SCIENCE_LABEL_COLOR if saved_is_tech else COST_LABEL_COLOR)
					if cards[i].has_meta("cost_label_icon"):
						(cards[i].get_meta("cost_label_icon") as TextureRect).texture = BEAKER_TEXTURE if saved_is_tech else COIN_TEXTURE
	else:
		_spawn_cards()

	_hand.spawn()
	_set_gold_display(gold)
	_set_science_display(science)
	_update_gold_label()

func _spawn_cards(count: int = card_count) -> void:
	for card in cards:
		_free_cost_label(card)
		card.queue_free()
	cards.clear()

	var all_ids := CardData.get_all().keys()

	# Build the pool: shuffle all ids, pick count with constraints.
	# Constraint 1: at least 1 building (if any are eligible).
	# Constraint 2: no duplicate techs.
	# Constraint 3: skip techs already researched.
	# Constraint 4: skip cards whose requires[] aren't all in techs_researched.
	var eligible_ids: Array[String] = []
	for id in all_ids:
		var reqs: Array = CardData.get_all().get(id, {}).get("requires", [])
		var reqs_met := reqs.all(func(r): return techs_researched.has(r))
		if not reqs_met:
			continue
		if CardData.get_type(id) == "Tech" and techs_researched.has(id):
			continue
		eligible_ids.append(id)

	var eligible_buildings: Array[String] = []
	for id in eligible_ids:
		if CardData.get_type(id) == "Building":
			eligible_buildings.append(id)

	var pool: Array[String] = []
	if not eligible_buildings.is_empty():
		pool.append(eligible_buildings[randi() % eligible_buildings.size()])
	var used_techs: Dictionary = {}
	var attempts := 0
	while pool.size() < count and attempts < count * 20:
		attempts += 1
		var id: String = eligible_ids[randi() % eligible_ids.size()]
		if CardData.get_type(id) == "Tech" and used_techs.has(id):
			continue
		if CardData.get_type(id) == "Tech":
			used_techs[id] = true
		pool.append(id)
	# Shuffle so the building isn't always first.
	pool.shuffle()

	var total_span := (count - 1) * CARD_SPACING + CARD_WIDTH
	var start_x    := (get_viewport_rect().size.x - total_span) / 2.0
	for i in count:
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
		_add_cost_label(card)

# Cost labels are separate nodes pinned to the shop slot, so they don't follow drags or hover.
func _add_cost_label(card: Node2D) -> void:
	var data: Dictionary = CardData.get_all().get(card.card_id, {})

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(COST_LABEL_WIDTH, COST_LABEL_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = COST_LABEL_BG_COLOR
	panel.add_theme_stylebox_override("panel", bg)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	var is_tech := CardData.get_type(card.card_id) == "Tech"
	var icon_rect := TextureRect.new()
	icon_rect.texture = BEAKER_TEXTURE if is_tech else COIN_TEXTURE
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_rect)

	var label := Label.new()
	label.text = "%d" % int(data.get("cost", 0))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", SCIENCE_LABEL_COLOR if is_tech else COST_LABEL_COLOR)
	label.add_theme_font_override("font", LABEL_FONT)
	label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(label)

	# card.position is its slot at spawn time; cards[] is still filling, so _shop_card_position would be off.
	panel.position = card.position + _cost_label_offset()
	add_child(panel)
	card.set_meta("cost_label", label)
	card.set_meta("cost_label_icon", icon_rect)
	card.set_meta("cost_label_root", panel)

func _cost_label_position(index: int) -> Vector2:
	return _shop_card_position(index) + _cost_label_offset()

func _cost_label_offset() -> Vector2:
	return Vector2((CARD_WIDTH - COST_LABEL_WIDTH) / 2.0, COST_LABEL_OFFSET_Y)

func _free_cost_label(card: Node2D) -> void:
	if card.has_meta("cost_label_root"):
		var root: Control = card.get_meta("cost_label_root")
		if is_instance_valid(root):
			root.queue_free()
		card.remove_meta("cost_label_root")
	if card.has_meta("cost_label"):
		card.remove_meta("cost_label")

func _free_shop_preview() -> void:
	if is_instance_valid(_shop_hover_preview):
		_shop_hover_preview.queue_free()
	_shop_hover_preview = null

func _preview_position(mouse: Vector2) -> Vector2:
	var preview_w := CARD_WIDTH * 2.0
	var right_of_center := mouse.x > get_viewport_rect().size.x / 2.0
	return Vector2(mouse.x - (preview_w if right_of_center else 0.0), mouse.y)

func _process(_delta: float) -> void:
	_hand.process_drag()
	var want_preview: bool = _shop_card_hovered != null and not _shop_card_hovered.dragging
	if want_preview:
		if not is_instance_valid(_shop_hover_preview):
			var preview := Node2D.new()
			preview.set_script(CARD_SCRIPT)
			preview.preview_only = true
			preview.scale = Vector2(2.0, 2.0)
			preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_top_layer.add_child(preview)
			_shop_hover_preview = preview
		if _shop_hover_preview.card_id != _shop_card_hovered.card_id:
			_shop_hover_preview.card_id = _shop_card_hovered.card_id
			_shop_hover_preview.queue_redraw()
		_shop_hover_preview.position = _preview_position(get_viewport().get_mouse_position())
	else:
		_free_shop_preview()

func _shop_card_position(index: int) -> Vector2:
	var n          := cards.size()
	var total_span := (n - 1) * CARD_SPACING + CARD_WIDTH
	var start_x    := (get_viewport_rect().size.x - total_span) / 2.0
	return Vector2(start_x + index * CARD_SPACING, 100)

func _connect_shop_hover(card: Node2D) -> void:
	var card_w: float = card.card_size.x
	var card_h: float = card.card_size.y
	card.drag_started.connect(func() -> void:
		_shop_card_dragging = card
		_shop_card_hovered = null
		card.z_index = 100
		get_tree().create_timer(0.3).timeout.connect(func() -> void:
			if is_instance_valid(card) and card.dragging:
				_drop_zone.show()
		)
	)
	card.drag_ended.connect(func() -> void:
		_shop_card_dragging = null
		card.z_index = 0
		_drop_zone.hide()
		var drop_y: float = card.global_position.y + card_h / 2.0
		if drop_y >= get_viewport_rect().size.y / 2.0:
			card.purchased.emit()
		else:
			var origin := _shop_card_position(card.get_meta("shop_index") as int)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(card, "scale",    Vector2.ONE, SHOP_TWEEN_T)
			tw.tween_property(card, "position", origin,      SHOP_TWEEN_T)
	)
	card.mouse_entered.connect(func() -> void:
		if _shop_card_dragging != null and _shop_card_dragging != card:
			return
		_shop_card_hovered = card
		# _hand.lift_card(card)
		var base  := _shop_card_position(card.get_meta("shop_index") as int)
		var offset := Vector2(card_w / 2.0 * (1.0 - SHOP_SCALE),
							  card_h / 2.0 * (1.0 - SHOP_SCALE) - SHOP_LIFT)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "scale",    Vector2(SHOP_SCALE, SHOP_SCALE), SHOP_TWEEN_T)
		tw.tween_property(card, "position", base + offset,                   SHOP_TWEEN_T)
	)
	card.mouse_exited.connect(func() -> void:
		if _shop_card_hovered == card:
			_shop_card_hovered = null
		_hand.drop_card(card)
		var base := _shop_card_position(card.get_meta("shop_index") as int)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "scale",    Vector2.ONE, SHOP_TWEEN_T)
		tw.tween_property(card, "position", base,        SHOP_TWEEN_T)
	)

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
		if cards[i].has_meta("cost_label_root"):
			tw.tween_property(cards[i].get_meta("cost_label_root"), "position", _cost_label_position(i), SHOP_TWEEN_T)

func _sell_hand_card(card: Node2D) -> void:
	var data: Dictionary = CardData.get_all().get(card.card_id, {})
	var refund: int = int(int(data.get("cost", 0)) / 2.0)
	if CardData.get_type(card.card_id) == "Tech":
		_change_science(refund)
	else:
		_change_gold(refund)
	_hand.remove_card(card)
	_update_gold_label()

func _update_gold_label() -> void:
	$UI/TitleRow/RefreshButton.text = "Refresh (%dg)" % refresh_cost

# Changes gold and animates the label counting from the old value to the new one.
func _change_gold(amount: int) -> void:
	if amount == 0:
		return
	gold += amount
	if _gold_tween:
		_gold_tween.kill()
	var label: Label = $UI/GoldRow/GoldLabel
	var flash := Color(1.0, 0.4, 0.4) if amount < 0 else Color(0.4, 1.0, 0.4)
	var duration := clampf(absf(amount) * 0.05, 0.25, 0.8)
	label.modulate = flash
	_gold_tween = create_tween().set_parallel(true)
	_gold_tween.tween_method(_set_gold_display, _displayed_gold, float(gold), duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_gold_tween.tween_property(label, "modulate", Color.WHITE, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _set_gold_display(value: float) -> void:
	_displayed_gold = value
	$UI/GoldRow/GoldLabel.text = "%d" % roundi(value)

func _set_science_display(value: float) -> void:
	_displayed_science = value
	$UI/GoldRow/ScienceLabel.text = "%d" % roundi(value)

const SCIENCE_LABEL_NORMAL := Color(0.4, 0.78, 1.0, 1)

func _change_science(amount: int) -> void:
	if amount == 0:
		return
	science += amount
	if _science_tween:
		_science_tween.kill()
	var label: Label = $UI/GoldRow/ScienceLabel
	var flash := Color(1.0, 0.4, 0.4) if amount < 0 else Color(0.4, 1.0, 0.4)
	var duration := clampf(absf(amount) * 0.05, 0.25, 0.8)
	label.add_theme_color_override("font_color", flash)
	_science_tween = create_tween().set_parallel(true)
	_science_tween.tween_method(_set_science_display, _displayed_science, float(science), duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_science_tween.tween_method(
		func(c: Color) -> void: label.add_theme_color_override("font_color", c),
		flash, SCIENCE_LABEL_NORMAL, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_card_purchased(card: Node2D) -> void:
	var data: Dictionary = CardData.get_all().get(card.card_id, {})
	var cost: int = data.get("cost", 0)
	var is_tech := CardData.get_type(card.card_id) == "Tech"
	var currency := science if is_tech else gold
	if currency < cost:
		_hand.drop_card(card)
		var origin := _shop_card_position(card.get_meta("shop_index") as int)
		var tw := create_tween()
		tw.tween_property(card, "modulate", Color.RED,   SHOP_TWEEN_T)
		tw.tween_property(card, "modulate", Color.WHITE, SHOP_TWEEN_T * 2)
		tw.set_parallel(true)
		tw.tween_property(card, "scale",    Vector2.ONE, SHOP_TWEEN_T * 2)
		tw.tween_property(card, "position", origin,      SHOP_TWEEN_T * 2)
		return
	if is_tech:
		_change_science(-cost)
		techs_researched.append(card.card_id)
	else:
		_change_gold(-cost)
		_hand.add_card(card.card_id)
	_free_cost_label(card)
	cards.erase(card)
	card.queue_free()
	_reindex_shop_cards()
	_update_gold_label()

func _on_refresh_pressed() -> void:
	if gold < refresh_cost:
		return
	_change_gold(-refresh_cost)
	refresh_cost += REFRESH_COST_INCREMENT
	_spawn_cards()
	_update_gold_label()

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
	var res: Vector2i = RESOLUTIONS[index]
	get_window().size = res
	get_window().move_to_center()

func quick_save() -> void:
	GameState.save_game(cards, _hand.hand_cards, gold, science)

func _on_save_exit_pressed() -> void:
	GameState.save_game(cards, _hand.hand_cards, gold, science)
	get_tree().change_scene_to_file("res://main.tscn")

func _on_town_button_pressed() -> void:
	GameState.hand_cards.assign(_hand.hand_cards)
	GameState.gold = gold
	GameState.science = science
	GameState.techs_researched.assign(techs_researched)
	get_tree().change_scene_to_file("res://town.tscn")
