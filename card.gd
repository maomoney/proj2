extends Node2D

signal purchased
signal mouse_entered
signal mouse_exited
signal drag_started
signal drag_ended

var card_size := Vector2(100, 140)
var card_id: String = ""
var dragging := false
var drag_offset := Vector2.ZERO
var _hovered := false
# Draws the sell value (half the cost) above the card. Shop toggles this for hovered/dragged hand cards.
var show_cost := false:
	set(value):
		if show_cost != value:
			show_cost = value
			queue_redraw()

const CORNER_RADIUS   := 6.0
const DRAG_THRESHOLD  := 5.0
const BG_COLOR        := Color(0.97, 0.95, 0.90)
const BORDER_COLOR    := Color(0.25, 0.25, 0.25)
const BORDER_WIDTH    := 2.0
const TEXT_COLOR      := Color(0.1,  0.1,  0.1)
const TEXT_COLOR_DIM  := Color(0.35, 0.35, 0.35)
const GOLD_COLOR      := Color(0.78, 0.58, 0.05)
const SEPARATOR_COLOR := Color(0.75, 0.73, 0.68)

const TYPE_COLORS := {
	"Building":     Color(0.52, 0.18, 0.80),
	"Unit": Color(0.80, 0.18, 0.18),
	"Tech":     Color(0.18, 0.40, 0.80),
}

func _get_rounded_rect_points(rect: Rect2, radius: float, segments: int = 8) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := [
		[Vector2(rect.position.x + rect.size.x - radius, rect.position.y + radius), -PI / 2.0],
		[Vector2(rect.position.x + rect.size.x - radius, rect.position.y + rect.size.y - radius), 0.0],
		[Vector2(rect.position.x + radius, rect.position.y + rect.size.y - radius), PI / 2.0],
		[Vector2(rect.position.x + radius, rect.position.y + radius), PI],
	]
	for corner in corners:
		var center: Vector2 = corner[0]
		var start: float = corner[1]
		for i in segments + 1:
			var angle := start + (PI / 2.0) * i / segments
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, card_size)
	var points := _get_rounded_rect_points(rect, CORNER_RADIUS)

	draw_polygon(points, PackedColorArray([BG_COLOR]))

	var border_pts := PackedVector2Array(points)
	border_pts.append(border_pts[0])
	draw_polyline(border_pts, BORDER_COLOR, BORDER_WIDTH, true)

	if card_id.is_empty():
		return
	var data: Dictionary = CardData.get_all().get(card_id, {})
	if data.is_empty():
		return

	var font       := ThemeDB.fallback_font
	var margin     := 7.0
	var text_width := card_size.x - margin * 2.0

	# Type
	var type_str: String = CardData.get_type(card_id)
	var type_col: Color  = TYPE_COLORS.get(type_str, Color.GRAY)
	draw_string(font, Vector2(margin, 15.0), type_str.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER, text_width, 9, type_col)

	draw_line(Vector2(margin, 21.0), Vector2(card_size.x - margin, 21.0), SEPARATOR_COLOR, 1.0)

	# Name
	var name_str: String = data.get("name", "")
	draw_string(font, Vector2(margin, 36.0), name_str,
			HORIZONTAL_ALIGNMENT_CENTER, text_width, 11, TEXT_COLOR)

	draw_line(Vector2(margin, 43.0), Vector2(card_size.x - margin, 43.0), SEPARATOR_COLOR, 1.0)

	# Description
	var desc_str: String = data.get("description", "")
	draw_multiline_string(font, Vector2(margin, 57.0), desc_str,
			HORIZONTAL_ALIGNMENT_LEFT, text_width, 9, 4, TEXT_COLOR_DIM)

	# Sell value, centered above the card (below would be off-screen for hand cards)
	if show_cost:
		var sell_value: int = int(data.get("cost", 0)) / 2
		draw_string(font, Vector2(0.0, -6.0), "%d g" % sell_value,
				HORIZONTAL_ALIGNMENT_CENTER, card_size.x, 14, GOLD_COLOR)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if dragging:
			return  # don't update hover state while dragging
		var local   := to_local(event.position)
		var in_card := Rect2(Vector2.ZERO, card_size).has_point(local)
		if in_card and not _hovered:
			_hovered = true
			mouse_entered.emit()
		elif not in_card and _hovered:
			_hovered = false
			mouse_exited.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local := to_local(event.position)
		var in_card := Rect2(Vector2.ZERO, card_size).has_point(local)
		if event.pressed and in_card:
			if event.double_click:
				purchased.emit()
				get_viewport().set_input_as_handled()
				return
			dragging = true
			drag_offset = local
			if _hovered:
				_hovered = false
				mouse_exited.emit()
			drag_started.emit()
			get_viewport().set_input_as_handled()
		elif not event.pressed and dragging:
			dragging = false
			drag_ended.emit()
	elif event is InputEventMouseMotion and dragging:
		position = event.position - drag_offset
		get_viewport().set_input_as_handled()
