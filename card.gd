extends Node2D

var card_size := Vector2(100, 140)
var card_id: String = ""
var is_active := false
var dragging := false
var drag_offset := Vector2.ZERO
var press_pos := Vector2.ZERO

const CORNER_RADIUS := 8.0
const DRAG_THRESHOLD := 5.0
const BG_COLOR        := Color(0.97, 0.95, 0.90)
const BORDER_COLOR    := Color(0.25, 0.25, 0.25)
const ACTIVE_BORDER   := Color(0.92, 0.38, 0.18)
const BORDER_WIDTH    := 2.0
const ACTIVE_BORDER_W := 4.0
const TEXT_COLOR      := Color(0.1, 0.1, 0.1)
const TEXT_COLOR_DIM  := Color(0.35, 0.35, 0.35)
const SEPARATOR_COLOR := Color(0.75, 0.73, 0.68)

const TYPE_COLORS := {
	"Spell":   Color(0.52, 0.18, 0.80),
	"Attack":  Color(0.80, 0.18, 0.18),
	"Defense": Color(0.18, 0.40, 0.80),
	"Item":    Color(0.18, 0.65, 0.28),
	"Buff":    Color(0.78, 0.58, 0.05),
	"Skill":   Color(0.08, 0.60, 0.70),
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

	var border_col := ACTIVE_BORDER if is_active else BORDER_COLOR
	var border_w   := ACTIVE_BORDER_W if is_active else BORDER_WIDTH
	var border_pts := PackedVector2Array(points)
	border_pts.append(border_pts[0])
	draw_polyline(border_pts, border_col, border_w, true)

	if card_id.is_empty():
		return
	var data: Dictionary = CardData.CARDS.get(card_id, {})
	if data.is_empty():
		return

	var font       := ThemeDB.fallback_font
	var margin     := 7.0
	var text_width := card_size.x - margin * 2.0

	# Type
	var type_str: String  = data.get("type", "")
	var type_col: Color   = TYPE_COLORS.get(type_str, Color.GRAY)
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local := to_local(event.position)
		var in_card := Rect2(Vector2.ZERO, card_size).has_point(local)
		if event.pressed:
			if in_card:
				dragging = true
				drag_offset = local
				press_pos = event.position
				get_viewport().set_input_as_handled()
		else:
			if dragging:
				if (event.position - press_pos).length() < DRAG_THRESHOLD:
					is_active = !is_active
					queue_redraw()
				dragging = false
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		position = event.position - drag_offset
		get_viewport().set_input_as_handled()
