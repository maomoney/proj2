extends Node2D

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const CARD_SCRIPT := preload("res://card.gd")
const REFRESH_COST_INITIAL = 2
const REFRESH_COST_INCREMENT = 1

const CARD_WIDTH := 100.0
const CARD_SPACING    := 110.0

const HAND_OVERLAP      := 20.0
const HAND_SCALE        := 1.25
const HAND_LIFT         := 20.0
const HAND_TWEEN_T      := 0.1
const HAND_ARC_RADIUS   := 1000.0
const HAND_ARC_SEP_DEG  := 5.0   # degrees between adjacent cards
const HAND_ARC_MAX_DEG  := 40.0  # maximum fan angle in degrees

const SHOP_SCALE    := 1.1
const SHOP_LIFT 	:= 0
const SHOP_TWEEN_T  := 0.1
const COST_LABEL_OFFSET_Y := 150.0  # below the card's bottom edge (card height 140)
const COST_LABEL_HEIGHT   := 20.0
const COST_LABEL_WIDTH    := 50.0   # background rect width, centered under the card
const COST_LABEL_BG_COLOR := Color(0.12, 0.12, 0.12, 0.85)
const COST_LABEL_COLOR    := Color(0.78, 0.58, 0.05)

var card_count := 10
var cards: Array[Node2D] = []
var hand_cards: Array[String] = []
var hand_nodes: Array[Node2D] = []
var hand_card_hovered: Node2D = null
var _shop_card_dragging: Node2D = null
var _hand_card_dragging: Node2D = null
var gold := 200
var _displayed_gold := 0.0
var _gold_tween: Tween
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
		_spawn_cards(card_states.size() if card_states.size() > 0 else card_count)
		for i in cards.size():
			if i < card_states.size():
				cards[i].position = card_states[i]["position"]
				cards[i].card_id  = card_states[i].get("card_id", cards[i].card_id)
				cards[i].queue_redraw()
	else:
		_spawn_cards()

	_spawn_hand()
	_set_gold_display(gold)
	_update_gold_label()

func _spawn_cards(count: int = card_count) -> void:
	for card in cards:
		_free_cost_label(card)
		card.queue_free()
	cards.clear()

	var all_ids    := CardData.get_all().keys()
	var building_ids := CardData.BUILDINGS.keys()
	var tech_ids     := CardData.TECHS.keys()

	# Build the pool: shuffle all ids, pick count with constraints.
	# Constraint 1: at least 1 building.
	# Constraint 2: no duplicate techs.
	var pool: Array[String] = []
	# Reserve one slot for a guaranteed building.
	pool.append(building_ids[randi() % building_ids.size()])
	# Fill remaining slots randomly, rejecting tech duplicates.
	var used_techs: Dictionary = {}
	var remaining := count - 1
	var attempts  := 0
	while pool.size() < count and attempts < count * 20:
		attempts += 1
		var id: String = all_ids[randi() % all_ids.size()]
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
	var label := Label.new()
	label.text = "%d g" % int(data.get("cost", 0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(COST_LABEL_WIDTH, COST_LABEL_HEIGHT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", COST_LABEL_COLOR)
	label.add_theme_font_size_override("font_size", 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = COST_LABEL_BG_COLOR
	# bg.set_corner_radius_all(4)
	label.add_theme_stylebox_override("normal", bg)
	# card.position is its slot at spawn time; cards[] is still filling, so _shop_card_position would be off.
	label.position = card.position + _cost_label_offset()
	add_child(label)
	card.set_meta("cost_label", label)

func _cost_label_position(index: int) -> Vector2:
	return _shop_card_position(index) + _cost_label_offset()

func _cost_label_offset() -> Vector2:
	return Vector2((CARD_WIDTH - COST_LABEL_WIDTH) / 2.0, COST_LABEL_OFFSET_Y)

func _free_cost_label(card: Node2D) -> void:
	if card.has_meta("cost_label"):
		var label: Label = card.get_meta("cost_label")
		if is_instance_valid(label):
			label.queue_free()
		card.remove_meta("cost_label")

func _spawn_hand() -> void:
	for n in hand_nodes:
		n.queue_free()
	hand_nodes.clear()
	hand_card_hovered = null
	_hand_card_dragging = null
	if hand_cards.is_empty():
		return

	for i in hand_cards.size():
		var card := Node2D.new()
		card.set_script(CARD_SCRIPT)
		card.name    = "Hand%d" % i
		card.card_id = hand_cards[i] as String
		add_child(card)
		card.z_index = i
		card.set_meta("hand_index", i)
		card.position = _hand_card_position(i)
		card.rotation = _hand_card_rotation(i)
		_connect_hand_hover(card, i)
		hand_nodes.append(card)

func _process(_delta: float) -> void:
	var card := _hand_card_dragging
	if card == null or hand_nodes.size() <= 1:
		return
	var n      := hand_nodes.size()
	var card_w := 100.0
	# Find the slot whose center x is nearest to the dragged card's center x.
	# Does not move the dragged card — only updates other cards' positions.
	var drag_center_x := card.position.x + card_w / 2.0
	var target_idx := 0
	var min_dist   := INF
	for j in n:
		var slot_cx := _hand_card_position(j).x + card_w / 2.0
		var d       := absf(drag_center_x - slot_cx)
		if d < min_dist:
			min_dist   = d
			target_idx = j
	var current_idx: int = card.get_meta("hand_index") as int
	if target_idx == current_idx:
		return
	# Reorder arrays.
	hand_cards.remove_at(current_idx)
	hand_cards.insert(target_idx, card.card_id)
	hand_nodes.erase(card)
	hand_nodes.insert(target_idx, card)
	# Update indices and tween non-dragged cards to new positions.
	for i in n:
		hand_nodes[i].set_meta("hand_index", i)
		hand_nodes[i].z_index = i
		if hand_nodes[i] != card:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(hand_nodes[i], "position", _hand_card_position(i),  HAND_TWEEN_T)
			tw.tween_property(hand_nodes[i], "rotation", _hand_card_rotation(i),  HAND_TWEEN_T)

func _shop_card_position(index: int) -> Vector2:
	var n          := cards.size()
	var total_span := (n - 1) * CARD_SPACING + CARD_WIDTH
	var start_x    := (get_viewport_rect().size.x - total_span) / 2.0
	return Vector2(start_x + index * CARD_SPACING, 100)

func _hand_card_angle(index: int) -> float:
	var n := hand_cards.size()
	if n <= 1:
		return -PI / 2.0
	var sep := minf(HAND_ARC_SEP_DEG, HAND_ARC_MAX_DEG / (n - 1))
	return -PI / 2.0 + (index - (n - 1) / 2.0) * deg_to_rad(sep)

func _hand_card_rotation(index: int) -> float:
	return _hand_card_angle(index) + PI / 2.0

func _hand_card_position(index: int) -> Vector2:
	var vp     := get_viewport_rect().size
	var center := Vector2(vp.x / 2.0, vp.y + HAND_ARC_RADIUS)
	var angle  := _hand_card_angle(index)
	var arc_pt := center + Vector2(cos(angle), sin(angle)) * HAND_ARC_RADIUS
	# Anchor card's bottom-center to the arc point.
	var card_w := 100.0
	var card_h := 140.0
	var local_bottom_center := Vector2(card_w / 2.0, card_h)
	return arc_pt - local_bottom_center.rotated(_hand_card_rotation(index))

func _connect_shop_hover(card: Node2D) -> void:
	var card_w: float = card.card_size.x
	var card_h: float = card.card_size.y
	card.drag_started.connect(func() -> void:
		_shop_card_dragging = card
		get_tree().create_timer(0.2).timeout.connect(func() -> void:
			if is_instance_valid(card) and card.dragging:
				_drop_zone.show()
		)
	)
	card.drag_ended.connect(func() -> void:
		_shop_card_dragging = null
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
		if _shop_card_dragging != null and _shop_card_dragging != card:
			return
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
		# If another card is hovered, cancel this drag and start on the hovered card instead.
		if hand_card_hovered != null and hand_card_hovered != card:
			card.dragging = false
			var hc := hand_card_hovered
			hand_card_hovered = null
			hc._hovered = false
			hc.dragging = true   # set before _unhover so rotation tween is skipped
			_unhover_hand_card(hc)
			hc.rotation = 0.0
			hc.drag_offset = hc.to_local(get_viewport().get_mouse_position())
			hc.drag_started.emit()
			return
		_hand_card_dragging = card
		card.rotation = 0.0
		card.show_cost = true
		get_tree().create_timer(0.2).timeout.connect(func() -> void:
			if is_instance_valid(card) and card.dragging:
				_sell_drop_zone.show()
		)
	)
	card.drag_ended.connect(func() -> void:
		_hand_card_dragging = null
		_sell_drop_zone.hide()
		card.show_cost = false
		var drop_y: float = card.global_position.y + card_h / 2.0
		if drop_y <= get_viewport_rect().size.y / 3.0:
			_sell_hand_card(card)
		else:
			var idx    := card.get_meta("hand_index") as int
			var origin := _hand_card_position(idx)
			var rot    := _hand_card_rotation(idx)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(card, "scale",    Vector2.ONE, HAND_TWEEN_T)
			tw.tween_property(card, "position", origin,      HAND_TWEEN_T)
			tw.tween_property(card, "rotation", rot,         HAND_TWEEN_T)
	)
	card.mouse_entered.connect(func() -> void:
		if hand_card_hovered == card:
			return
		if _hand_card_dragging != null and _hand_card_dragging != card:
			return
		if hand_card_hovered != null:
			_unhover_hand_card(hand_card_hovered)
		hand_card_hovered = card
		card.show_cost = true
		_lift_card(card)
		var idx          := card.get_meta("hand_index") as int
		var vp           := get_viewport_rect().size
		var arc_center_x := _hand_card_position(idx).x + card_w / 2.0
		var hover_pos    := Vector2(
			arc_center_x - card_w * HAND_SCALE / 2.0,
			vp.y - HAND_LIFT - card_h * HAND_SCALE)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "scale",    Vector2(HAND_SCALE, HAND_SCALE), HAND_TWEEN_T)
		tw.tween_property(card, "position", hover_pos,                       HAND_TWEEN_T)
		tw.tween_property(card, "rotation", 0.0,                             HAND_TWEEN_T)
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
	if not card.dragging:
		card.show_cost = false
	_drop_card(card)
	var idx  := card.get_meta("hand_index") as int
	var base := _hand_card_position(idx)
	var rot  := _hand_card_rotation(idx)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "scale",    Vector2.ONE, HAND_TWEEN_T)
	tw.tween_property(card, "position", base,        HAND_TWEEN_T)
	if not card.dragging:
		tw.tween_property(card, "rotation", rot, HAND_TWEEN_T)

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
		if cards[i].has_meta("cost_label"):
			tw.tween_property(cards[i].get_meta("cost_label"), "position", _cost_label_position(i), SHOP_TWEEN_T)

func _sell_hand_card(card: Node2D) -> void:
	var data: Dictionary = CardData.get_all().get(card.card_id, {})
	var refund: int = data.get("cost", 0) / 2
	_change_gold(refund)
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
		var rot    := _hand_card_rotation(i)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(hand_nodes[i], "position", target,      HAND_TWEEN_T)
		tw.tween_property(hand_nodes[i], "rotation", rot,         HAND_TWEEN_T)
		tw.tween_property(hand_nodes[i], "scale",    Vector2.ONE, HAND_TWEEN_T)
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
	var label: Label = $UI/GoldLabel
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
	$UI/GoldLabel.text = "Gold: %d" % roundi(value)

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
	_change_gold(-cost)
	hand_cards.append(card.card_id)
	_free_cost_label(card)
	cards.erase(card)
	card.queue_free()
	_reindex_shop_cards()
	_spawn_hand()
	_update_gold_label()

func _on_refresh_pressed() -> void:
	if gold < refresh_cost:
		return
	_change_gold(-refresh_cost)
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
