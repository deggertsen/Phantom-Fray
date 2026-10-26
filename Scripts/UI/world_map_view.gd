extends Control
class_name WorldMapView

## The world front, drawn: Natural Earth coastlines, the two tears' ground hatched over the land,
## the front as a magenta line with arrows where it pushes, the tears ringed, and every city as a
## marker whose color is its state. A difficulty filter dims the cities that do not match.
## Cities are buttons; the markers themselves are drawn in _draw.

signal city_pressed(action: StringName)
signal city_hovered

const COLOR_OCEAN := Color("070812")
const COLOR_LAND := Color("171d3d")
const COLOR_COAST := Color("2c3663")
const COLOR_GRID := Color("151b35")
const COLOR_FRONT := Color("ff3fb5")
const COLOR_CONSUMED_FILL := Color("1a0a24")
const COLOR_HATCH := Color("3b1f52")
const COLOR_TEXT := Color("c4cde0")
const COLOR_SELECT := Color.WHITE
const STATE_COLORS := {
	WorldMap.STATE_SAFE: Color("3a5a7a"),
	WorldMap.STATE_THREATENED: Color("7fe3ff"),
	WorldMap.STATE_DANGER: Color("ffb347"),
	WorldMap.STATE_OVERRUN: Color("ff3fb5"),
	WorldMap.STATE_CONSUMED: Color("1a1024"),
}

## Built once: the coastline packed, and each tear's ground clipped to the land.
static var _rings: Array[PackedVector2Array] = []
static var _consumed_pieces: Array[PackedVector2Array] = []

var _entries: Array[Dictionary] = []
var _selected_id: String = ""
var _filter: String = "all"
var _interactive: bool = true
var _home_id: String = ""

## entries are WorldMap.city_entries. filter is "all", "easy", "medium", or "hard".
func show_world(entries: Array[Dictionary], selected_id: String, filter: String = "all", home_id: String = "", interactive: bool = true) -> void:
	_entries = entries
	_selected_id = selected_id
	_filter = filter
	_home_id = home_id
	_interactive = interactive
	_on_resized()

func _ready() -> void:
	clip_contents = true
	resized.connect(_on_resized)
	_prepare_geometry()

static func _prepare_geometry() -> void:
	if not _rings.is_empty():
		return
	for ring in WorldCoastline.RINGS:
		var packed := PackedVector2Array()
		for point in ring:
			packed.append(point)
		_rings.append(packed)
	var zones := WorldMap.zone_polygons()
	for key in zones:
		var zone: PackedVector2Array = zones[key]
		for ring in _rings:
			# https://docs.godotengine.org/en/stable/classes/class_geometry2d.html#class-geometry2d-method-intersect-polygons
			for piece in Geometry2D.intersect_polygons(zone, ring):
				if piece.size() >= 3:
					_consumed_pieces.append(piece)

## The map keeps WorldCoastline's aspect inside the control, centered.
func _frame() -> Rect2:
	var aspect := WorldCoastline.WIDTH / WorldCoastline.HEIGHT
	var width := size.x
	var height := width / aspect
	if height > size.y:
		height = size.y
		width = height * aspect
	return Rect2((size - Vector2(width, height)) * 0.5, Vector2(width, height))

func _to_screen(point: Vector2) -> Vector2:
	var frame := _frame()
	return frame.position + Vector2(point.x / WorldCoastline.WIDTH * frame.size.x, point.y / WorldCoastline.HEIGHT * frame.size.y)

func _to_screen_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(_to_screen(point))
	return out

func _on_resized() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_rebuild_cities()
	queue_redraw()

func _matches(entry: Dictionary) -> bool:
	return _filter == "all" or String(entry.get("difficulty", "")) == _filter

## Cities that can be fought in place their names first, so a safe city's name gives way.
func _rebuild_cities() -> void:
	for child in get_children():
		child.queue_free()
	var placed: Array[Rect2] = []
	var ordered := _entries.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _label_rank(a) < _label_rank(b)
	)
	for entry in ordered:
		_add_city(entry, placed)

func _label_rank(entry: Dictionary) -> int:
	if entry.get("id", "") == _selected_id or entry.get("id", "") == _home_id:
		return 0
	match String(entry.get("state", "")):
		WorldMap.STATE_OVERRUN: return 1
		WorldMap.STATE_DANGER: return 2
		WorldMap.STATE_THREATENED: return 3
		WorldMap.STATE_CONSUMED: return 4
		_: return 5

## The name sits below the marker, or above, right, or left when another name is already
## there. A name with nowhere to go is hidden; the marker stays and the button still works.
func _place_label(center: Vector2, label_size: Vector2, placed: Array[Rect2]) -> Rect2:
	var candidates := [
		Vector2(center.x - label_size.x * 0.5, center.y + 9.0),
		Vector2(center.x - label_size.x * 0.5, center.y - 9.0 - label_size.y),
		Vector2(center.x + 10.0, center.y - label_size.y * 0.5),
		Vector2(center.x - 10.0 - label_size.x, center.y - label_size.y * 0.5),
	]
	for candidate in candidates:
		var origin: Vector2 = candidate
		origin.x = clampf(origin.x, 2.0, size.x - label_size.x - 2.0)
		origin.y = clampf(origin.y, 2.0, size.y - label_size.y - 2.0)
		var rect := Rect2(origin, label_size)
		var clear := true
		for other in placed:
			if other.intersects(rect.grow(1.0)):
				clear = false
				break
		if clear:
			return rect
	return Rect2()

func _add_city(entry: Dictionary, placed: Array[Rect2]) -> void:
	var city_id := String(entry.get("id", ""))
	var center := _to_screen(entry.get("point", Vector2.ZERO))
	var state := String(entry.get("state", WorldMap.STATE_SAFE))
	var matches := _matches(entry)
	var label := Label.new()
	label.text = String(entry.get("name", ""))
	label.add_theme_font_size_override("font_size", 14)
	var text_color := COLOR_TEXT
	if state == WorldMap.STATE_SAFE:
		text_color = Color("6b7a94")
	elif state == WorldMap.STATE_CONSUMED:
		text_color = Color("8b7fa3")
	if city_id == _home_id:
		text_color = STATE_COLORS[WorldMap.STATE_THREATENED]
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", COLOR_OCEAN)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label_size := label.get_minimum_size()
	var label_rect := _place_label(center, label_size, placed)
	var marker := Rect2(center - Vector2(12, 12), Vector2(24, 24))
	label.visible = label_rect.size.x > 0.0
	if label.visible:
		placed.append(label_rect)
	else:
		label_rect = marker
	var origin := label_rect.position
	var bounds := marker.merge(label_rect).grow(4.0)
	var button := Button.new()
	button.position = bounds.position
	button.size = bounds.size
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not _interactive
	button.mouse_filter = Control.MOUSE_FILTER_STOP if _interactive else Control.MOUSE_FILTER_IGNORE
	button.modulate = Color(1, 1, 1, 1.0 if matches else 0.25)
	button.set_meta(&"menu_action", StringName("world_city_%s" % city_id))
	button.set_meta(&"primary", city_id == _selected_id)
	var empty := StyleBoxEmpty.new()
	for state_name in ["normal", "disabled", "focus"]:
		button.add_theme_stylebox_override(state_name, empty)
	button.add_theme_stylebox_override("hover", _hover_style(0.10))
	button.add_theme_stylebox_override("pressed", _hover_style(0.22))
	button.add_theme_stylebox_override("hover_pressed", _hover_style(0.22))
	add_child(button)
	label.position = origin - bounds.position
	button.add_child(label)
	button.pressed.connect(func() -> void: city_pressed.emit(StringName("world_city_%s" % city_id)))
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			city_hovered.emit()
	)

func _hover_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_SELECT, alpha * 0.6)
	style.border_color = Color(COLOR_SELECT, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style

func _draw() -> void:
	var frame := _frame()
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_OCEAN)
	# Equator and tropics-ish guide lines, and the prime meridian.
	for lat in [0.0, 45.0, -45.0]:
		var y := _to_screen(WorldMap.project(0.0, lat)).y
		draw_line(Vector2(frame.position.x, y), Vector2(frame.end.x, y), COLOR_GRID, 1.0)
	var x0 := _to_screen(WorldMap.project(0.0, 0.0)).x
	draw_line(Vector2(x0, frame.position.y), Vector2(x0, frame.end.y), COLOR_GRID, 1.0)
	for ring in _rings:
		var polygon := _to_screen_polygon(ring)
		draw_colored_polygon(polygon, COLOR_LAND)
	for ring in _rings:
		var polygon := _to_screen_polygon(ring)
		polygon.append(polygon[0])
		draw_polyline(polygon, COLOR_COAST, 1.0, true)
	for piece in _consumed_pieces:
		var polygon := _to_screen_polygon(piece)
		draw_colored_polygon(polygon, Color(COLOR_CONSUMED_FILL, 0.6))
		_hatch(polygon)
	var zones := WorldMap.zone_polygons()
	for key in zones:
		var outline := _to_screen_polygon(zones[key])
		outline.append(outline[0])
		draw_polyline(outline, Color(COLOR_FRONT, 0.06), 28.0, true)
		draw_polyline(outline, Color(COLOR_FRONT, 0.12), 10.0, true)
		draw_polyline(outline, COLOR_FRONT, 1.6, true)
	for arrow in WorldMap.arrows():
		_draw_arrow(_to_screen(arrow["point"]), deg_to_rad(float(arrow["degrees"])))
	for entry in _entries:
		if entry.has("origin"):
			var center := _to_screen(entry["point"])
			draw_arc(center, 14.0, 0.0, TAU, 40, Color(COLOR_FRONT, 0.5), 1.0, true)
			draw_arc(center, 8.0, 0.0, TAU, 32, COLOR_FRONT, 1.2, true)
	for entry in _entries:
		_draw_city(entry)

func _hatch(polygon: PackedVector2Array) -> void:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	var spacing := 6.0
	var offset := bounds.position.x - bounds.size.y
	while offset < bounds.end.x:
		var line := PackedVector2Array([Vector2(offset, bounds.end.y), Vector2(offset + bounds.size.y, bounds.position.y)])
		for piece in Geometry2D.intersect_polyline_with_polygon(line, polygon):
			if piece.size() >= 2:
				draw_line(piece[0], piece[piece.size() - 1], COLOR_HATCH, 1.2)
		offset += spacing

func _draw_arrow(center: Vector2, angle: float) -> void:
	var points := PackedVector2Array([Vector2(0, -7), Vector2(5, 3), Vector2(0, 0.5), Vector2(-5, 3)])
	var rotated := PackedVector2Array()
	for point in points:
		rotated.append(center + point.rotated(angle))
	draw_colored_polygon(rotated, Color("ff7fd0"))

func _draw_city(entry: Dictionary) -> void:
	var state := String(entry.get("state", WorldMap.STATE_SAFE))
	var center := _to_screen(entry.get("point", Vector2.ZERO))
	var color: Color = STATE_COLORS.get(state, COLOR_TEXT)
	var alpha := 1.0 if _matches(entry) else 0.25
	var city_id := String(entry.get("id", ""))
	match state:
		WorldMap.STATE_SAFE:
			draw_circle(center, 3.0, Color(color, alpha))
		WorldMap.STATE_CONSUMED:
			draw_circle(center, 4.0, Color(color, alpha))
			draw_arc(center, 4.5, 0.0, TAU, 20, Color("6b4a8a", alpha), 1.5, true)
		_:
			var glow := 0.3 if state == WorldMap.STATE_THREATENED else 0.22
			draw_circle(center, 11.0, Color(color, glow * alpha * 0.5))
			draw_circle(center, 7.0, Color(color, glow * alpha))
			draw_circle(center, 4.5, Color(color, alpha))
	if city_id == _selected_id and _interactive:
		draw_arc(center, 9.5, 0.0, TAU, 32, COLOR_SELECT, 1.6, true)
