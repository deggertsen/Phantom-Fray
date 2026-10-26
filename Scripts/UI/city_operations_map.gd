extends Control
class_name CityOperationsMap

## One section of a city: its districts as a short path, the front line one column right of the
## last seal, and the phantoms' ground hatched beyond it. Districts are buttons; a sealed one
## carries a check, an open one a cyan edge, a locked one a dashed edge. See WorldMap.section.

signal node_pressed(action: StringName)
signal node_hovered

const COLOR_GROUND := Color("0a0d1f")
const COLOR_GRID := Color("1e2650")
const COLOR_FRONT := Color("ff3fb5")
const COLOR_HATCH := Color("3b1f52")
const COLOR_CONSUMED_FILL := Color("1a0a24")
const COLOR_EDGE := Color("2a3356")
const COLOR_EDGE_LIT := Color("56dff5")
const COLOR_EDGE_OPEN := Color("8fb8c8")
const COLOR_OPEN := Color("56dff5")
const COLOR_SEALED := Color("56dff5")
const COLOR_LOCKED := Color("4a3360")
const COLOR_TEXT := Color("edf7ff")
const COLOR_MUTED := Color("8da4bd")
const NODE_SIZE := Vector2(132, 60)

var _section: Dictionary = {}
var _sealed: Array = []
var _selected_id: String = ""
var _highlight_id: String = ""
var _interactive: bool = true
var _sealed_before: int = -1

## sealed are the district ids sealed in this section so far. On results, highlight_id is the
## district just sealed and sealed_before where the line stood before it.
func show_section(section: Dictionary, sealed: Array, selected_id: String, interactive: bool = true, highlight_id: String = "", sealed_before: int = -1) -> void:
	_section = section
	_sealed = sealed
	_selected_id = selected_id
	_interactive = interactive
	_highlight_id = highlight_id
	_sealed_before = sealed_before
	_on_resized()

func _ready() -> void:
	clip_contents = true
	resized.connect(_on_resized)

func _on_resized() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_rebuild_nodes()
	queue_redraw()

func _to_screen(point: Vector2) -> Vector2:
	return Vector2(point.x / WorldMap.MAP_SIZE.x * size.x, point.y / WorldMap.MAP_SIZE.y * size.y)

func _rebuild_nodes() -> void:
	for child in get_children():
		child.queue_free()
	for node in _section.get("nodes", []):
		_add_node(node)

func _status(node_id: String) -> String:
	return WorldMap.node_status(_section, _sealed, node_id)

func _add_node(node: Dictionary) -> void:
	var node_id := String(node.get("id", ""))
	var status := _status(node_id)
	var center := _to_screen(node.get("point", Vector2.ZERO))
	var button := Button.new()
	button.position = center - NODE_SIZE * 0.5
	button.size = NODE_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not (_interactive and status == "open")
	button.mouse_filter = Control.MOUSE_FILTER_STOP if _interactive else Control.MOUSE_FILTER_IGNORE
	button.set_meta(&"menu_action", StringName("node_%s" % node_id))
	button.set_meta(&"primary", node_id == _selected_id)
	var fill := Color("0a0c1c", 0.92)
	var edge := COLOR_EDGE
	var dashed := false
	match status:
		"sealed":
			fill = Color(COLOR_SEALED, 0.18)
			edge = COLOR_SEALED
		"open":
			edge = COLOR_OPEN
		_:
			edge = COLOR_LOCKED
			dashed = true
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge if node_id != _highlight_id else Color.WHITE
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	if node_id == _selected_id and _interactive:
		style.border_color = Color.WHITE
	for state_name in ["normal", "disabled", "focus"]:
		button.add_theme_stylebox_override(state_name, style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(COLOR_OPEN, 0.22)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	add_child(button)
	button.set_meta(&"dashed", dashed)
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 8
	stack.offset_right = -8
	stack.offset_top = 6
	stack.offset_bottom = -6
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Label.new()
	name_label.text = ("✓ " if status == "sealed" else "") + String(node.get("name", ""))
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", COLOR_TEXT if status != "locked" else Color("8b7fa3"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kind_label := Label.new()
	kind_label.text = WorldMap.kind_label(String(node.get("kind", "")))
	kind_label.add_theme_font_size_override("font_size", 12)
	kind_label.add_theme_color_override("font_color", Color("7fe3ff") if status == "sealed" else (COLOR_MUTED if status == "open" else Color("6b5a84")))
	kind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(name_label)
	stack.add_child(kind_label)
	button.add_child(stack)
	button.pressed.connect(func() -> void: node_pressed.emit(StringName("node_%s" % node_id)))
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			node_hovered.emit()
	)

## The line sits just right of the last sealed column; nothing sealed puts it before the first.
func _front_x(sealed_count: int) -> float:
	var columns := WorldMap.COLUMN_X
	var x := columns[0] - 100.0
	if sealed_count > 0:
		var column := mini(sealed_count, columns.size()) - 1
		x = columns[column] + 100.0 if sealed_count < columns.size() else WorldMap.MAP_SIZE.x + 40.0
	return x

func _front_points(sealed_count: int) -> PackedVector2Array:
	var x := _front_x(sealed_count)
	var points := PackedVector2Array()
	var steps := 24
	for step in range(steps + 1):
		var t := float(step) / steps
		var wobble := sin(t * TAU * 1.5) * 18.0
		points.append(_to_screen(Vector2(x + wobble, t * WorldMap.MAP_SIZE.y)))
	return points

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_GROUND)
	for x in range(0, int(WorldMap.MAP_SIZE.x) + 1, 100):
		var sx := _to_screen(Vector2(x, 0)).x
		draw_line(Vector2(sx, 0), Vector2(sx, size.y), COLOR_GRID, 1.0)
	for y in range(0, int(WorldMap.MAP_SIZE.y) + 1, 100):
		var sy := _to_screen(Vector2(0, y)).y
		draw_line(Vector2(0, sy), Vector2(size.x, sy), COLOR_GRID, 1.0)
	var sealed_count := _sealed.size()
	var front := _front_points(sealed_count)
	if _front_x(sealed_count) < WorldMap.MAP_SIZE.x:
		var zone := PackedVector2Array(front)
		zone.append(Vector2(size.x, size.y))
		zone.append(Vector2(size.x, 0.0))
		draw_colored_polygon(zone, Color(COLOR_CONSUMED_FILL, 0.45))
		_hatch(zone)
		if _sealed_before >= 0 and _sealed_before != sealed_count:
			var old := _front_points(_sealed_before)
			draw_polyline(old, Color(COLOR_FRONT, 0.35), 1.5, true)
		draw_polyline(front, Color(COLOR_FRONT, 0.12), 14.0, true)
		draw_polyline(front, COLOR_FRONT, 2.0, true)
	var by_id := {}
	for node in _section.get("nodes", []):
		by_id[node["id"]] = node
	for edge in _section.get("edges", []):
		var a: Dictionary = by_id.get(edge[0], {})
		var b: Dictionary = by_id.get(edge[1], {})
		if a.is_empty() or b.is_empty():
			continue
		var color := COLOR_EDGE
		if String(edge[0]) in _sealed and String(edge[1]) in _sealed:
			color = COLOR_EDGE_LIT
		elif String(edge[0]) in _sealed and _status(String(edge[1])) == "open":
			color = COLOR_EDGE_OPEN
		draw_line(_to_screen(a["point"]), _to_screen(b["point"]), color, 2.0, true)
	for node in _section.get("nodes", []):
		if _status(String(node["id"])) == "locked":
			_draw_dashed_box(_to_screen(node["point"]))

func _draw_dashed_box(center: Vector2) -> void:
	var rect := Rect2(center - NODE_SIZE * 0.5 - Vector2(3, 3), NODE_SIZE + Vector2(6, 6))
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position]
	for index in 4:
		var from: Vector2 = corners[index]
		var to: Vector2 = corners[index + 1]
		var length := from.distance_to(to)
		var travelled := 0.0
		while travelled < length:
			var step := minf(6.0, length - travelled)
			draw_line(from.lerp(to, travelled / length), from.lerp(to, (travelled + step) / length), Color(COLOR_LOCKED, 0.9), 1.5)
			travelled += 12.0

func _hatch(polygon: PackedVector2Array) -> void:
	var spacing := 14.0
	var offset := -size.y
	while offset < size.x:
		var line := PackedVector2Array([Vector2(offset, size.y), Vector2(offset + size.y, 0.0)])
		for piece in Geometry2D.intersect_polyline_with_polygon(line, polygon):
			if piece.size() >= 2:
				draw_line(piece[0], piece[piece.size() - 1], COLOR_HATCH, 1.5)
		offset += spacing
