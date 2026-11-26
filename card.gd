extends Node2D

static var _icon_cache: Dictionary = {}

static func _get_icon_tex(png: Texture2D, cell: Vector2i, color: Color) -> ImageTexture:
	var key := "%d_%d_%d_%x" % [png.get_rid().get_id(), cell.x, cell.y, color.to_rgba32()]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var src: Image = png.get_image()
	src.convert(Image.FORMAT_RGBA8)
	var region := Rect2i(cell.x * 16, cell.y * 16, 16, 16)
	var img: Image = src.get_region(region)
	for y in 16:
		for x in 16:
			var px := img.get_pixel(x, y)
			if px.a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, 1.0 - px.r))
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[key] = tex
	return tex

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
var preview_only := false
# Draws the sell value (half the cost) above the card. Shop toggles this for hovered/dragged hand cards.
var show_cost := false:
	set(value):
		if show_cost != value:
			show_cost = value
			queue_redraw()

const CORNER_RADIUS   := 6.0
const DRAG_THRESHOLD  := 5.0
const BG_COLOR        := Color(0.97, 0.95, 0.90)
const BORDER_COLOR    := Color(0.0, 0.0, 0.0)
const BORDER_WIDTH    := 1.0
const TEXT_COLOR      := Color(0.1,  0.1,  0.1)
const TEXT_COLOR_DIM  := Color(0.35, 0.35, 0.35)
const GOLD_COLOR      := Color(0.949, 0.761, 0.051, 1)
const SEPARATOR_COLOR := Color(0.75, 0.73, 0.68)

const COIN_TEXTURE   := preload("res://assets/coin.png")
const BEAKER_TEXTURE := preload("res://assets/beaker.png")
const LABEL_FONT     := preload("res://assets/Kubasta.ttf")
const ICON_BUILDING_PNG := preload("res://assets/Icons_Map_Markers.png")
const ICON_BUILDING     := Vector2i(0, 3)
const ICON_UNIT_PNG     := preload("res://assets/Icons_RPG.png")
const ICON_UNIT         := Vector2i(0, 0)
const ICON_TECH_PNG     := preload("res://assets/Icons_Alchemy.png")
const ICON_TECH         := Vector2i(2, 6)

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

	var font       := LABEL_FONT
	var margin     := 7.0
	var text_width := card_size.x - margin * 2.0

	# Type with icon
	var type_str: String = CardData.get_type(card_id)
	var name_str: String = data.get("name", "")
	var type_col: Color  = TYPE_COLORS.get(type_str, Color.GRAY)
	var icon_png: Texture2D = {"Building": ICON_BUILDING_PNG, "Unit": ICON_UNIT_PNG, "Tech": ICON_TECH_PNG}.get(type_str, ICON_BUILDING_PNG)
	var icon_cell: Vector2i = {"Building": ICON_BUILDING,    "Unit": ICON_UNIT,    "Tech": ICON_TECH   }.get(type_str, Vector2i(0, 0))
	var icon_dst := Rect2(Vector2(margin, 4.0), Vector2(12.0, 12.0))
	draw_texture_rect(_get_icon_tex(icon_png, icon_cell, type_col), icon_dst, false)
	draw_string(font, Vector2(margin + 14.0, 15.0), name_str.to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, text_width - 14.0, 8, type_col)

	# draw_line(Vector2(margin, 21.0), Vector2(card_size.x - margin, 21.0), SEPARATOR_COLOR, 1.0)

	var tile_size = card_size.x - margin * 2.0
	draw_rect(Rect2(Vector2(margin, 22.0), Vector2(tile_size, int(tile_size * 2 / 3) )), SEPARATOR_COLOR)


	# Description
	var desc_str: String = data.get("description", "")
	draw_multiline_string(font, Vector2(margin, 90.0), desc_str,
			HORIZONTAL_ALIGNMENT_LEFT, text_width, 7, 4, TEXT_COLOR_DIM)

	# Sell value, centered above the card (below would be off-screen for hand cards)
	if show_cost:
		var sell_value: int = int(int(data.get("cost", 0)) / 2.0)
		var num_str := "%d" % sell_value
		var coin_size := Vector2(20.0, 20.0)
		var str_w := font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var total_w := coin_size.x + 3.0 + str_w
		var start_x := (card_size.x - total_w) / 2.0
		var coin_y := -(coin_size.y + 3.0)
		var coin_center_y := coin_y + coin_size.y * 0.5
		draw_texture_rect(COIN_TEXTURE, Rect2(Vector2(start_x, coin_y), coin_size), false)
		draw_string(font, Vector2(start_x + coin_size.x + 3.0, coin_center_y + 5.0), num_str,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD_COLOR)
	
	if preview_only:
		var cost: int = int(data.get("cost", 0))
		var is_tech := CardData.get_type(card_id) == "Tech"
		var icon := BEAKER_TEXTURE if is_tech else COIN_TEXTURE
		var cost_color := Color(0.4, 0.78, 1.0, 1) if is_tech else GOLD_COLOR
		var num_str := "%d" % cost
		var coin_size := Vector2(20.0, 20.0)
		var str_w := font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var total_w := coin_size.x + 3.0 + str_w
		var start_x := (card_size.x - total_w) / 2.0
		var pad := Vector2(6.0, 4.0)
		var bg_w := total_w + pad.x * 2.0
		var bg_h := coin_size.y + pad.y * 2.0
		var bg_x := (card_size.x - bg_w) / 2.0
		var below_y := card_size.y + 6.0
		draw_rect(Rect2(Vector2(bg_x, below_y), Vector2(bg_w, bg_h)), Color(0.12, 0.12, 0.12, 0.85))
		start_x = bg_x + pad.x
		var icon_y := below_y + pad.y
		var icon_center_y := icon_y + coin_size.y * 0.5
		draw_texture_rect(icon, Rect2(Vector2(start_x, icon_y), coin_size), false)
		draw_string(font, Vector2(start_x + coin_size.x + 3.0, icon_center_y + 5.0), num_str,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cost_color)

func _input(event: InputEvent) -> void:
	if preview_only:
		return
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
	if preview_only:
		return
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
