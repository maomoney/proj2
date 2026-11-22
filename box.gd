extends Node2D

var box_size := Vector2(150, 100)
var is_active := false
var dragging := false
var drag_offset := Vector2.ZERO
var press_pos := Vector2.ZERO

const DRAG_THRESHOLD := 5.0
const INACTIVE_COLOR := Color(0.25, 0.47, 0.82)
const ACTIVE_COLOR := Color(0.92, 0.38, 0.18)
const BORDER_COLOR := Color(0.08, 0.08, 0.08)
const BORDER_WIDTH := 3.0

func _ready() -> void:
	position = Vector2(200, 150)

func _draw() -> void:
	var fill := ACTIVE_COLOR if is_active else INACTIVE_COLOR
	draw_rect(Rect2(Vector2.ZERO, box_size), fill)
	draw_rect(Rect2(Vector2.ZERO, box_size), BORDER_COLOR, false, BORDER_WIDTH)

	var font := ThemeDB.fallback_font
	var font_size := 16
	var label := "ACTIVE" if is_active else "INACTIVE"
	var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_pos := Vector2((box_size.x - text_w) * 0.5, box_size.y * 0.5 + font_size * 0.35)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local := to_local(event.position)
		var in_box := Rect2(Vector2.ZERO, box_size).has_point(local)

		if event.pressed:
			if in_box:
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
