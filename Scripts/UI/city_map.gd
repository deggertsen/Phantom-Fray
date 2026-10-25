extends Control
class_name CityMap

## The breach city as a drawn map: districts, a river, the roads between sites, and the front
## line between reclaimed ground and the breach. Each operation is a site. The front line sits
## where the sealed count puts it, so sealing a site visibly pushes it forward. Later a world map
## picks the city; for now there is only this one.

signal site_pressed(action: StringName)
signal site_hovered

const COLOR_GROUND := Color("070b16")
const COLOR_DISTRICT := Color("0a1122")
const COLOR_DISTRICT_EDGE := Color("1c2a4a")
const COLOR_RIVER := Color("123049")
const COLOR_GRID := Color(0.34, 0.87, 0.96, 0.05)
const COLOR_FRONT := Color("ff5d78")
const COLOR_SEALED := Color("5cf2ae")
const COLOR_SEALED_FILL := Color("0b2a22")
const COLOR_LIVE := Color("ff3dc8")
const COLOR_SELECT := Color("56dff5")
const COLOR_LOCKED := Color("3a4a6a")
const COLOR_MAW_LOCKED := Color("6b3a4c")
const COLOR_TEXT := Color("edf7ff")
const COLOR_MUTED := Color("8da4bd")

## Site centers as fractions of the map, in campaign order. Sealed ground spreads left to right.
const SITES := {
	"first_light": Vector2(0.173, 0.706),
	"widen_the_ring": Vector2(0.327, 0.492),
	"chens_gambit": Vector2(0.573, 0.367),
	"double_breach": Vector2(0.683, 0.667),
	"open_arc": Vector2(0.678, 0.206),
	"the_maw": Vector2(0.849, 0.09),
}
## Which side of its marker each site's label sits on, chosen so no two labels meet whatever
## state the sites are in.
const LABEL_SIDES := {
	"first_light": &"right",
	"widen_the_ring": &"left",
	"chens_gambit": &"below",
	"double_breach": &"right",
	"open_arc": &"right",
	"the_maw": &"left",
}
const ROADS := [
	["first_light", "widen_the_ring"],
	["widen_the_ring", "chens_gambit"],
	["chens_gambit", "double_breach"],
	["chens_gambit", "open_arc"],
	["open_arc", "the_maw"],
]
## The front line's x at the top, quarter, middle, three quarters, and bottom of the map, for each
## sealed count. Every sealed site sits left of it and the next live one right of it. Six sealed
## has no line: the city is reclaimed.
const FRONT_LINES := [
	[0.08, 0.09, 0.10, 0.10, 0.09],
	[0.22, 0.24, 0.25, 0.26, 0.25],
	[0.40, 0.45, 0.47, 0.49, 0.50],
	[0.62, 0.63, 0.62, 0.61, 0.60],
	[0.60, 0.62, 0.73, 0.78, 0.78],
	[0.76, 0.77, 0.80, 0.81, 0.81],
]
const DISTRICTS := [
	[Vector2(60, 90), Vector2(250, 70), Vector2(290, 210), Vector2(120, 250)],
	[Vector2(90, 310), Vector2(260, 280), Vector2(320, 430), Vector2(150, 480)],
	[Vector2(40, 480), Vector2(150, 490), Vector2(210, 610), Vector2(60, 650)],
	[Vector2(300, 70), Vector2(520, 50), Vector2(560, 180), Vector2(330, 220)],
	[Vector2(340, 250), Vector2(560, 220), Vector2(600, 370), Vector2(380, 410)],
	[Vector2(380, 440), Vector2(610, 410), Vector2(680, 570), Vector2(430, 600)],
	[Vector2(590, 50), Vector2(790, 40), Vector2(800, 270), Vector2(620, 290)],
	[Vector2(640, 310), Vector2(800, 300), Vector2(800, 530), Vector2(700, 550)],
]
const RIVER := [Vector2(0, 540), Vector2(100, 528), Vector2(200, 575), Vector2(300, 630), Vector2(420, 672), Vector2(560, 690), Vector2(700, 672), Vector2(820, 660)]
## DISTRICTS and RIVER are drawn in this space and scaled to the map's size.
const ART_SIZE := Vector2(820, 724)

var _entries: Array[Dictionary] = []
var _selected_id: String = ""
var _highlight_id: String = ""
var _sealed_before: int = -1
var _interactive: bool = true

## entries are MissionCatalog.operation_entries. selected_id gets the selection ring. On results,
## sealed_before draws where the front stood before this mission and highlight_id marks the site
## just sealed; the sites are not buttons there.
func show_sites(entries: Array[Dictionary], selected_id: String, interactive: bool = true, sealed_before: int = -1, highlight_id: String = "") -> void:
	_entries = entries
	_selected_id = selected_id
	_interactive = interactive
	_sealed_before = sealed_before
	_highlight_id = highlight_id
	_on_resized()

func _ready() -> void:
	clip_contents = true
	resized.connect(_on_resized)

## Site buttons and labels are placed in pixels, so a new size places them again.
func _on_resized() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_rebuild_sites()
	queue_redraw()

static func sealed_count(entries: Array[Dictionary]) -> int:
	var count := 0
	for entry in entries:
		if entry.get("cleared", false):
			count += 1
	return count

func _rebuild_sites() -> void:
	for child in get_children():
		child.queue_free()
	for entry in _entries:
		var mission_id := String(entry.get("id", ""))
		if not SITES.has(mission_id):
			continue
		_add_site(entry, _site_point(mission_id))

## A transparent button over the marker and its label; the marker itself is drawn in _draw.
func _add_site(entry: Dictionary, center: Vector2) -> void:
	var mission_id := String(entry.get("id", ""))
	var cleared: bool = entry.get("cleared", false)
	var unlocked: bool = entry.get("unlocked", false)
	var live := unlocked and not cleared
	var radius := _marker_radius(entry)
	var title := Label.new()
	title.text = String(entry.get("title", ""))
	title.add_theme_font_size_override("font_size", 18 if live or mission_id == _selected_id else 17)
	title.add_theme_color_override("font_color", COLOR_TEXT if unlocked else COLOR_MUTED)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", COLOR_GROUND)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_color_override("font_outline_color", COLOR_GROUND)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mission_id == _highlight_id:
		sub.text = "SEALED"
		sub.add_theme_color_override("font_color", COLOR_SEALED)
	elif cleared:
		var best := float(entry.get("best_seconds", 0.0))
		sub.text = "BEST %s" % _clock(best) if best > 0.0 else "SEALED"
		sub.add_theme_color_override("font_color", COLOR_MUTED)
	elif live:
		sub.text = "LIVE BREACH"
		sub.add_theme_color_override("font_color", Color("ff8bdd"))
	else:
		sub.text = "BEHIND THE LINE"
		sub.add_theme_color_override("font_color", COLOR_MUTED)
	var label_size := Vector2(maxf(title.get_minimum_size().x, sub.get_minimum_size().x), title.get_minimum_size().y + sub.get_minimum_size().y)
	var side: StringName = LABEL_SIDES.get(mission_id, &"right")
	var label_origin := Vector2(center.x + radius + 10.0, center.y - label_size.y * 0.5)
	if side == &"below":
		label_origin = Vector2(center.x - label_size.x * 0.5, center.y + radius + 8.0)
	elif side == &"left":
		label_origin = Vector2(center.x - radius - 10.0 - label_size.x, center.y - label_size.y * 0.5)
	label_origin.x = clampf(label_origin.x, 4.0, size.x - label_size.x - 4.0)
	var bounds := Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0).merge(Rect2(label_origin, label_size)).grow(6.0)
	var button := Button.new()
	button.position = bounds.position
	button.size = bounds.size
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not (_interactive and unlocked)
	button.mouse_filter = Control.MOUSE_FILTER_STOP if _interactive else Control.MOUSE_FILTER_IGNORE
	button.set_meta(&"menu_action", StringName("site_%s" % mission_id))
	button.set_meta(&"primary", mission_id == _selected_id)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, empty)
	button.add_theme_stylebox_override("hover", _hover_style(0.10))
	button.add_theme_stylebox_override("pressed", _hover_style(0.22))
	button.add_theme_stylebox_override("hover_pressed", _hover_style(0.22))
	add_child(button)
	title.position = label_origin - bounds.position
	sub.position = title.position + Vector2(0.0, title.get_minimum_size().y)
	if side != &"right":
		var align := HORIZONTAL_ALIGNMENT_CENTER if side == &"below" else HORIZONTAL_ALIGNMENT_RIGHT
		title.size.x = label_size.x
		sub.size.x = label_size.x
		title.horizontal_alignment = align
		sub.horizontal_alignment = align
	button.add_child(title)
	button.add_child(sub)
	button.pressed.connect(func() -> void: site_pressed.emit(StringName("site_%s" % mission_id)))
	# A disabled button still reports the pointer entering; a locked site stays silent.
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			site_hovered.emit()
	)

func _hover_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_SELECT, alpha)
	style.border_color = Color(COLOR_SELECT, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style

func _marker_radius(entry: Dictionary) -> float:
	var mission_id := String(entry.get("id", ""))
	var unlocked: bool = entry.get("unlocked", false)
	if unlocked and not entry.get("cleared", false):
		return 38.0
	if mission_id == _highlight_id:
		return 34.0
	if mission_id == "the_maw":
		return 28.0
	return 21.0

func _site_point(mission_id: String) -> Vector2:
	var fraction: Vector2 = SITES.get(mission_id, Vector2(0.5, 0.5))
	return Vector2(fraction.x * size.x, fraction.y * size.y)

func _art(point: Vector2) -> Vector2:
	return Vector2(point.x / ART_SIZE.x * size.x, point.y / ART_SIZE.y * size.y)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_GROUND)
	for x in range(0, int(size.x), 32):
		draw_line(Vector2(x, 0), Vector2(x, size.y), COLOR_GRID)
	for y in range(0, int(size.y), 32):
		draw_line(Vector2(0, y), Vector2(size.x, y), COLOR_GRID)
	var river := PackedVector2Array()
	for point in RIVER:
		river.append(_art(point))
	draw_polyline(river, COLOR_RIVER, 20.0 * size.x / ART_SIZE.x, true)
	for district in DISTRICTS:
		var polygon := PackedVector2Array()
		for point in district:
			polygon.append(_art(point))
		draw_colored_polygon(polygon, COLOR_DISTRICT)
		polygon.append(polygon[0])
		draw_polyline(polygon, COLOR_DISTRICT_EDGE, 1.5, true)
	var sealed := sealed_count(_entries)
	_draw_breach_zone(sealed)
	_draw_roads()
	if _sealed_before >= 0 and _sealed_before != sealed and _sealed_before < FRONT_LINES.size():
		_draw_dashed(_front_points(_sealed_before), Color(COLOR_FRONT, 0.4), 2.0, 6.0, 8.0)
	if sealed < FRONT_LINES.size():
		_draw_dashed(_front_points(sealed), COLOR_FRONT, 3.0, 12.0, 8.0)
	for entry in _entries:
		var mission_id := String(entry.get("id", ""))
		if SITES.has(mission_id):
			_draw_marker(entry, _site_point(mission_id))

## The front line, top to bottom, through its five control points.
func _front_points(sealed: int) -> PackedVector2Array:
	var controls: Array = FRONT_LINES[clampi(sealed, 0, FRONT_LINES.size() - 1)]
	var points := PackedVector2Array()
	var steps := 32
	for step in range(steps + 1):
		var t := float(step) / steps * (controls.size() - 1)
		var index := mini(floori(t), controls.size() - 2)
		var local := t - index
		var before: float = controls[maxi(index - 1, 0)]
		var from: float = controls[index]
		var to: float = controls[index + 1]
		var after: float = controls[mini(index + 2, controls.size() - 1)]
		# https://docs.godotengine.org/en/stable/classes/class_@globalscope.html#class-globalscope-method-cubic-interpolate
		var x := cubic_interpolate(from, to, before, after, local)
		points.append(Vector2(x * size.x, float(step) / steps * size.y))
	return points

## The ground still held by the breach: everything right of the front, tinted and hatched.
func _draw_breach_zone(sealed: int) -> void:
	if sealed >= FRONT_LINES.size():
		return
	var zone := _front_points(sealed)
	zone.append(Vector2(size.x, size.y))
	zone.append(Vector2(size.x, 0.0))
	draw_colored_polygon(zone, Color(COLOR_FRONT, 0.035))
	var hatch := Color(COLOR_FRONT, 0.16)
	var spacing := 18.0
	var offset := -size.y
	while offset < size.x:
		var line := PackedVector2Array([Vector2(offset, size.y), Vector2(offset + size.y, 0.0)])
		# https://docs.godotengine.org/en/stable/classes/class_geometry2d.html#class-geometry2d-method-intersect-polyline-with-polygon
		for piece in Geometry2D.intersect_polyline_with_polygon(line, zone):
			if piece.size() >= 2:
				draw_line(piece[0], piece[piece.size() - 1], hatch, 2.0)
		offset += spacing

func _draw_roads() -> void:
	for road in ROADS:
		var from_entry := _entry(String(road[0]))
		var to_entry := _entry(String(road[1]))
		if from_entry.is_empty() or to_entry.is_empty():
			continue
		var reclaimed: bool = from_entry.get("cleared", false) and to_entry.get("unlocked", false)
		var color := Color(COLOR_SEALED, 0.5) if reclaimed else Color(COLOR_LOCKED, 0.9)
		_draw_dashed(PackedVector2Array([_site_point(String(road[0])), _site_point(String(road[1]))]), color, 2.0, 5.0, 7.0)

func _draw_marker(entry: Dictionary, center: Vector2) -> void:
	var mission_id := String(entry.get("id", ""))
	var cleared: bool = entry.get("cleared", false)
	var unlocked: bool = entry.get("unlocked", false)
	var radius := _marker_radius(entry)
	if mission_id == _selected_id and _interactive:
		draw_circle(center, radius + 20.0, Color(COLOR_SELECT, 0.06))
		draw_circle(center, radius + 10.0, Color(COLOR_SELECT, 0.12))
	if mission_id == _highlight_id:
		draw_circle(center, radius + 12.0, Color(COLOR_SEALED, 0.14))
	if cleared:
		draw_circle(center, radius, COLOR_SEALED_FILL)
		draw_arc(center, radius, 0.0, TAU, 48, COLOR_SEALED, 3.0 if mission_id == _highlight_id else 2.0, true)
		var tick := radius * 0.42
		draw_polyline(PackedVector2Array([center + Vector2(-tick, 0.0), center + Vector2(-tick * 0.25, tick * 0.7), center + Vector2(tick, -tick * 0.6)]), COLOR_SEALED, 3.0, true)
		if mission_id == _selected_id and _interactive:
			draw_arc(center, radius + 5.0, 0.0, TAU, 48, COLOR_SELECT, 2.0, true)
	elif unlocked:
		draw_arc(center, radius, 0.0, TAU, 64, COLOR_SELECT, 2.0, true)
		draw_circle(center, radius * 0.62, COLOR_LIVE)
		# A rift: a lens of two arcs that meet top and bottom, where their circles cross.
		var core := radius * 0.62
		draw_arc(center + Vector2(core * 0.55, 0.0), core * 0.8, PI * 0.73, PI * 1.27, 16, Color("1a0414"), 2.5, true)
		draw_arc(center - Vector2(core * 0.55, 0.0), core * 0.8, -PI * 0.27, PI * 0.27, 16, Color("1a0414"), 2.5, true)
	else:
		var edge := COLOR_MAW_LOCKED if mission_id == "the_maw" else COLOR_LOCKED
		var dashes := 14
		for dash in dashes:
			var start := TAU * dash / dashes
			draw_arc(center, radius, start, start + TAU / dashes * 0.55, 6, edge, 2.0, true)
		_draw_lock(center, Color("7f93ad") if mission_id != "the_maw" else Color("b05a72"))

func _draw_lock(center: Vector2, color: Color) -> void:
	var body := Rect2(center + Vector2(-7.0, -2.0), Vector2(14.0, 11.0))
	draw_rect(body, color, false, 2.0)
	draw_arc(center + Vector2(0.0, -2.0), 5.0, PI, TAU, 12, color, 2.0, true)

## A dashed polyline whose dash pattern runs on across segments.
func _draw_dashed(points: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	var drawing := true
	var left := dash
	for index in range(points.size() - 1):
		var from := points[index]
		var to := points[index + 1]
		var length := from.distance_to(to)
		var travelled := 0.0
		while travelled < length:
			var step := minf(left, length - travelled)
			var a := from.lerp(to, travelled / length)
			var b := from.lerp(to, (travelled + step) / length)
			if drawing:
				draw_line(a, b, color, width, true)
			travelled += step
			left -= step
			if left <= 0.0:
				drawing = not drawing
				left = dash if drawing else gap

func _entry(mission_id: String) -> Dictionary:
	for entry in _entries:
		if entry.get("id", "") == mission_id:
			return entry
	return {}

func _clock(seconds: float) -> String:
	var whole := maxi(floori(seconds), 0)
	return "%d:%02d" % [whole / 60, whole % 60]
