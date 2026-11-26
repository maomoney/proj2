extends RefCounted
class_name HandManager

const CARD_SCRIPT      := preload("res://card.gd")
const HAND_BASE_SCALE  := 1.2
const HAND_SCALE       := 1.4
const HAND_LIFT        := 20.0
const HAND_TWEEN_T     := 0.1
const HAND_ARC_RADIUS  := 1000.0
const HAND_ARC_SEP_DEG := 5.0
const HAND_ARC_MAX_DEG := 40.0

signal sell_requested(card: Node2D)

var hand_cards: Array[String] = []
var hand_nodes: Array[Node2D] = []
var hand_card_hovered: Node2D = null
var _hand_card_dragging: Node2D = null
var show_sell_value := true

var _parent: Node2D
var _top_layer: CanvasLayer
var _sell_drop_zone: ColorRect

func setup(parent: Node2D, top_layer: CanvasLayer, sell_drop_zone: ColorRect = null) -> void:
	_parent = parent
	_top_layer = top_layer
	_sell_drop_zone = sell_drop_zone

func spawn() -> void:
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
		_parent.add_child(card)
		card.z_index = i
		card.set_meta("hand_index", i)
		card.position = card_position(i)
		card.rotation = card_rotation(i)
		card.scale = Vector2(HAND_BASE_SCALE, HAND_BASE_SCALE)
		_connect_hover(card, i)
		hand_nodes.append(card)

func process_drag() -> void:
	var card := _hand_card_dragging
	if card == null or hand_nodes.size() <= 1:
		return
	var n      := hand_nodes.size()
	var card_w := 100.0 * HAND_BASE_SCALE
	var drag_center_x := card.position.x + card_w / 2.0
	var target_idx := 0
	var min_dist   := INF
	for j in n:
		var slot_cx := card_position(j).x + card_w / 2.0
		var d       := absf(drag_center_x - slot_cx)
		if d < min_dist:
			min_dist   = d
			target_idx = j
	var current_idx: int = card.get_meta("hand_index") as int
	if target_idx == current_idx:
		return
	hand_cards.remove_at(current_idx)
	hand_cards.insert(target_idx, card.card_id)
	hand_nodes.erase(card)
	hand_nodes.insert(target_idx, card)
	for i in n:
		hand_nodes[i].set_meta("hand_index", i)
		hand_nodes[i].z_index = i
		if hand_nodes[i] != card:
			var tw := _parent.create_tween().set_parallel(true)
			tw.tween_property(hand_nodes[i], "position", card_position(i), HAND_TWEEN_T)
			tw.tween_property(hand_nodes[i], "rotation", card_rotation(i), HAND_TWEEN_T)

func add_card(card_id: String) -> void:
	hand_cards.append(card_id)
	var i := hand_cards.size() - 1
	var card := Node2D.new()
	card.set_script(CARD_SCRIPT)
	card.name    = "Hand%d" % i
	card.card_id = card_id
	_parent.add_child(card)
	card.z_index = i
	card.set_meta("hand_index", i)
	card.scale = Vector2(HAND_BASE_SCALE, HAND_BASE_SCALE)
	# Start below the viewport
	var vp_h := _parent.get_viewport_rect().size.y
	card.position = card_position(i) + Vector2(0.0, vp_h)
	card.rotation = card_rotation(i)
	_connect_hover(card, i)
	hand_nodes.append(card)
	# Tween existing cards to updated positions, new card slides up
	var tw := _parent.create_tween().set_parallel(true)
	for j in hand_nodes.size():
		hand_nodes[j].set_meta("hand_index", j)
		hand_nodes[j].z_index = j
		tw.tween_property(hand_nodes[j], "position", card_position(j), HAND_TWEEN_T * 3)
		tw.tween_property(hand_nodes[j], "rotation", card_rotation(j), HAND_TWEEN_T * 3)

func remove_card(card: Node2D) -> void:
	remove_and_reindex(card)

func remove_and_reindex(card: Node2D) -> void:
	var idx: int = card.get_meta("hand_index") as int
	hand_cards.remove_at(idx)
	hand_nodes.erase(card)
	if hand_card_hovered == card:
		hand_card_hovered = null
	card.queue_free()
	for i in hand_nodes.size():
		hand_nodes[i].set_meta("hand_index", i)
		hand_nodes[i].z_index = i
		var tw := _parent.create_tween().set_parallel(true)
		tw.tween_property(hand_nodes[i], "position", card_position(i), HAND_TWEEN_T)
		tw.tween_property(hand_nodes[i], "rotation", card_rotation(i), HAND_TWEEN_T)
		tw.tween_property(hand_nodes[i], "scale", Vector2(HAND_BASE_SCALE, HAND_BASE_SCALE), HAND_TWEEN_T)

func card_angle(index: int) -> float:
	var n := hand_cards.size()
	if n <= 1:
		return -PI / 2.0
	var sep := minf(HAND_ARC_SEP_DEG, HAND_ARC_MAX_DEG / (n - 1))
	return -PI / 2.0 + (index - (n - 1) / 2.0) * deg_to_rad(sep)

func card_rotation(index: int) -> float:
	return card_angle(index) + PI / 2.0

func card_position(index: int) -> Vector2:
	var vp     := _parent.get_viewport_rect().size
	var center := Vector2(vp.x / 2.0, vp.y + HAND_ARC_RADIUS)
	var angle  := card_angle(index)
	var arc_pt := center + Vector2(cos(angle), sin(angle)) * HAND_ARC_RADIUS
	var card_w := 100.0 * HAND_BASE_SCALE
	var card_h := 140.0 * HAND_BASE_SCALE
	var local_bottom_center := Vector2(card_w / 2.0, card_h)
	return arc_pt - local_bottom_center.rotated(card_rotation(index))

func lift_card(card: Node2D) -> void:
	var global := card.global_position
	card.reparent(_top_layer)
	card.global_position = global

func drop_card(card: Node2D) -> void:
	if card.get_parent() != _parent:
		var global := card.global_position
		card.reparent(_parent)
		card.global_position = global

func unhover(card: Node2D) -> void:
	if not card.dragging:
		card.show_cost = false
	drop_card(card)
	var idx  := card.get_meta("hand_index") as int
	var tw := _parent.create_tween().set_parallel(true)
	tw.tween_property(card, "scale",    Vector2(HAND_BASE_SCALE, HAND_BASE_SCALE), HAND_TWEEN_T)
	tw.tween_property(card, "position", card_position(idx), HAND_TWEEN_T)
	if not card.dragging:
		tw.tween_property(card, "rotation", card_rotation(idx), HAND_TWEEN_T)

func _connect_hover(card: Node2D, base_z: int) -> void:
	card.set_meta("base_z", base_z)
	var card_w: float = card.card_size.x
	var card_h: float = card.card_size.y
	card.drag_started.connect(func() -> void:
		if hand_card_hovered != null and hand_card_hovered != card:
			card.dragging = false
			var hc := hand_card_hovered
			hand_card_hovered = null
			hc._hovered = false
			hc.dragging = true
			unhover(hc)
			hc.rotation = 0.0
			hc.drag_offset = hc.to_local(_parent.get_viewport().get_mouse_position())
			hc.drag_started.emit()
			return
		_hand_card_dragging = card
		card.rotation = 0.0
		card.show_cost = show_sell_value
		_parent.get_tree().create_timer(0.2).timeout.connect(func() -> void:
			if is_instance_valid(card) and card.dragging and _sell_drop_zone != null:
				_sell_drop_zone.show()
		)
	)
	card.drag_ended.connect(func() -> void:
		_hand_card_dragging = null
		if _sell_drop_zone != null:
			_sell_drop_zone.hide()
		card.show_cost = false
		var drop_y: float = card.global_position.y + card_h / 2.0
		if drop_y <= _parent.get_viewport_rect().size.y / 3.0:
			sell_requested.emit(card)
		else:
			var idx    := card.get_meta("hand_index") as int
			var tw := _parent.create_tween().set_parallel(true)
			tw.tween_property(card, "scale",    Vector2(HAND_BASE_SCALE, HAND_BASE_SCALE), HAND_TWEEN_T)
			tw.tween_property(card, "position", card_position(idx), HAND_TWEEN_T)
			tw.tween_property(card, "rotation", card_rotation(idx), HAND_TWEEN_T)
	)
	card.mouse_entered.connect(func() -> void:
		if hand_card_hovered == card:
			return
		if _hand_card_dragging != null and _hand_card_dragging != card:
			return
		if hand_card_hovered != null:
			unhover(hand_card_hovered)
		hand_card_hovered = card
		card.show_cost = show_sell_value
		lift_card(card)
		var idx          := card.get_meta("hand_index") as int
		var vp           := _parent.get_viewport_rect().size
		var arc_center_x := card_position(idx).x + card_w / 2.0
		var hover_pos    := Vector2(
			arc_center_x - card_w * HAND_SCALE / 2.0,
			vp.y - HAND_LIFT - card_h * HAND_SCALE)
		var tw := _parent.create_tween().set_parallel(true)
		tw.tween_property(card, "scale",    Vector2(HAND_SCALE, HAND_SCALE), HAND_TWEEN_T)
		tw.tween_property(card, "position", hover_pos,                       HAND_TWEEN_T)
		tw.tween_property(card, "rotation", 0.0,                             HAND_TWEEN_T)
	)
	card.mouse_exited.connect(func() -> void:
		if hand_card_hovered == card:
			hand_card_hovered = null
		unhover(card)
	)
