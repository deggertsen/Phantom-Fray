extends Control
class_name WorldMapView

## The world front, drawn: Natural Earth coastlines, the two tears' ground hatched over the land,
## the front as a magenta line with arrows where it pushes, the tears ringed, and every city as a
## marker whose color is its state. A difficulty filter dims the cities that do not match.
## The view is a window onto the projected map. At the whole world the regions are the buttons;
## zoomed to a region its cities are. Opening a city closes the window in on it. The window
## eases between boxes, and the buttons come back only once it settles. Lines and markers keep
## their size on screen at every zoom.

## world_region_<id> or world_city_<id>.
signal action_pressed(action: StringName)
signal hovered
## The window reached its box: a region, the world, or the city being opened.
signal window_settled

## A region zoom and its reverse, and the closing in on a city before its section opens.
const ZOOM_SECONDS := 0.5
const CITY_ZOOM_SECONDS := 0.45

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

## Built once: the coastline packed and closed, the land as one mesh in projected units, and
## each tear's ground clipped to the land. The land is a mesh drawn through the window's
## transform because a 1300-point polygon at a city's zoom, in screen pixels, did not draw.
static var _land: ArrayMesh
static var _rings: Array[PackedVector2Array] = []
static var _outlines: Array[PackedVector2Array] = []
static var _consumed_pieces: Array[PackedVector2Array] = []

var _entries: Array[Dictionary] = []
var _selected_id: String = ""
var _filter: String = "all"
var _interactive: bool = true
var _home_id: String = ""
## "" is the whole world.
var _region_id: String = ""
## The city being opened while the window closes in on it.
var _focus_city_id: String = ""
## The window eases from one box to the other; _t runs 0 to 1.
var _from_box: Rect2
var _to_box: Rect2
var _has_box: bool = false
var _t: float = 1.0
var _seconds: float = ZOOM_SECONDS
## The window this frame, and projected-to-screen for it.
var _view: Rect2
var _xform := Transform2D.IDENTITY
## The buttons and their labels, rebuilt when the window settles.
var _layer: Control

func _init() -> void:
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	set_process(false)

## entries are WorldMap.city_entries. filter is "all", "easy", "medium", or "hard". region_id is a
## WorldMap region, or "" for the whole world. A change of region eases the window to it.
func show_world(entries: Array[Dictionary], selected_id: String, filter: String = "all", home_id: String = "", interactive: bool = true, region_id: String = "") -> void:
	_entries = entries
	_selected_id = selected_id
	_filter = filter
	_home_id = home_id
	_interactive = interactive
	_region_id = region_id
	_focus_city_id = ""
	var target := _region_box(region_id)
	if not _has_box:
		_jump(target)
	elif target != _to_box:
		_animate_to(target, ZOOM_SECONDS)
	elif is_zooming():
		queue_redraw()
	else:
		_on_resized()

## Starts the window on a city, so showing its region next eases out from it.
func start_at_city(city_id: String) -> void:
	_jump(WorldMap.city_box(WorldMap.city(city_id).get("point", Vector2.ZERO)))

## Closes the window in on a city; window_settled fires when it is there.
func zoom_to_city(city_id: String) -> void:
	_focus_city_id = city_id
	_animate_to(WorldMap.city_box(WorldMap.city(city_id).get("point", Vector2.ZERO)), CITY_ZOOM_SECONDS)

## Ends the zoom now, as if it had run out.
func finish_zoom() -> void:
	if is_zooming():
		_settle()

func is_zooming() -> bool:
	return _t < 1.0

func region_id() -> String:
	return _region_id

## What is visible, in projected map units.
func window() -> Rect2:
	var a := _fit(_from_box)
	var b := _fit(_to_box)
	if _t >= 1.0:
		return b
	# Ease in and out; the size moves in log space so the zoom reads at an even pace.
	var e := _t * _t * (3.0 - 2.0 * _t)
	var center := a.get_center().lerp(b.get_center(), e)
	var width := exp(lerpf(log(a.size.x), log(b.size.x), e))
	var window_size := Vector2(width, width / _aspect())
	return Rect2(center - window_size * 0.5, window_size)

func _ready() -> void:
	clip_contents = true
	resized.connect(_on_resized)
	_prepare_geometry()

func _process(delta: float) -> void:
	_t = minf(_t + delta / _seconds, 1.0)
	if _t >= 1.0:
		_settle()
		return
	_update_view()
	queue_redraw()

static func _prepare_geometry() -> void:
	if not _rings.is_empty():
		return
	var vertices := PackedVector2Array()
	var indices := PackedInt32Array()
	for ring in WorldCoastline.RINGS:
		var packed := PackedVector2Array()
		for point in ring:
			packed.append(point)
		_rings.append(packed)
		var closed := packed.duplicate()
		closed.append(packed[0])
		_outlines.append(closed)
		# https://docs.godotengine.org/en/stable/classes/class_geometry2d.html#class-geometry2d-method-triangulate-polygon
		for index in Geometry2D.triangulate_polygon(packed):
			indices.append(vertices.size() + index)
		vertices.append_array(packed)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	_land = ArrayMesh.new()
	_land.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var zones := WorldMap.zone_polygons()
	for key in zones:
		var zone: PackedVector2Array = zones[key]
		for ring in _rings:
			# https://docs.godotengine.org/en/stable/classes/class_geometry2d.html#class-geometry2d-method-intersect-polygons
			for piece in Geometry2D.intersect_polygons(zone, ring):
				if piece.size() >= 3:
					_consumed_pieces.append(piece)

func _region_box(region_id: String) -> Rect2:
	if region_id == "":
		return WorldMap.world_box()
	return WorldMap.region(region_id).get("box", WorldMap.world_box())

func _jump(box: Rect2) -> void:
	_from_box = box
	_to_box = box
	_has_box = true
	_t = 1.0
	set_process(false)
	_on_resized()

func _animate_to(box: Rect2, seconds: float) -> void:
	_from_box = window() if _has_box else box
	_to_box = box
	_has_box = true
	_t = 0.0
	_seconds = seconds
	_clear_layer()
	set_process(true)
	_update_view()
	queue_redraw()

func _settle() -> void:
	_t = 1.0
	_from_box = _to_box
	set_process(false)
	_on_resized()
	window_settled.emit()

func _aspect() -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return WorldCoastline.WIDTH / WorldCoastline.HEIGHT
	return size.x / size.y

## A box grown to the control's aspect around its center, then kept on the map where it is
## smaller than the map; the whole world sits centered in the control, as it always has.
func _fit(box: Rect2) -> Rect2:
	var aspect := _aspect()
	var fitted := box.size
	if fitted.x / maxf(fitted.y, 0.001) < aspect:
		fitted.x = fitted.y * aspect
	else:
		fitted.y = fitted.x / aspect
	var world := WorldMap.world_box()
	var origin := box.get_center() - fitted * 0.5
	for axis in 2:
		if fitted[axis] >= world.size[axis]:
			origin[axis] = world.get_center()[axis] - fitted[axis] * 0.5
		else:
			origin[axis] = clampf(origin[axis], world.position[axis], world.end[axis] - fitted[axis])
	return Rect2(origin, fitted)

func _update_view() -> void:
	_view = window()
	var scale_factor := size.x / _view.size.x if _view.size.x > 0.0 else 1.0
	_xform = Transform2D(0.0, Vector2(scale_factor, scale_factor), 0.0, -_view.position * scale_factor)

func _to_screen(point: Vector2) -> Vector2:
	return _xform * point

func _to_screen_polygon(points: PackedVector2Array) -> PackedVector2Array:
	return _xform * points

func _on_resized() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_update_view()
	if is_zooming() or _focus_city_id != "":
		_clear_layer()
	elif _region_id == "":
		_rebuild_regions()
	else:
		_rebuild_cities()
	queue_redraw()

func _matches(entry: Dictionary) -> bool:
	return _filter == "all" or String(entry.get("difficulty", "")) == _filter

## Hidden now, freed at the end of the frame, so nothing old can be pointed at meanwhile. The
## button that asked for the zoom may still be in its pressed signal, so it is not removed here.
func _clear_layer() -> void:
	for child in _layer.get_children():
		(child as Control).visible = false
		child.queue_free()

# --- Buttons --------------------------------------------------------------------------------

## The whole world: one button per region over its box, its name and what it holds to fight.
func _rebuild_regions() -> void:
	_clear_layer()
	var selected_region := WorldMap.region_of(_selected_id)
	for region_data in WorldMap.regions():
		var region_id := String(region_data["id"])
		var in_reach := 0
		for entry in _entries:
			if entry.get("id", "") in region_data["cities"] and entry.get("playable", false) and not entry.get("liberated", false) and _matches(entry):
				in_reach += 1
		var box: Rect2 = region_data["box"]
		var bounds := Rect2(_to_screen(box.position), box.size * _xform.get_scale())
		var button := _map_button(StringName("world_region_%s" % region_id), bounds, region_id == selected_region, 0.18)
		button.modulate = Color(1, 1, 1, 1.0 if in_reach > 0 or _filter == "all" else 0.35)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", -2)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title := _outlined(String(region_data["name"]).to_upper(), 16, COLOR_TEXT)
		var count := _outlined("%d IN REACH" % in_reach if in_reach > 0 else "NOTHING TO FIGHT", 12, STATE_COLORS[WorldMap.STATE_THREATENED] if in_reach > 0 else Color("6b7a94"))
		for line in [title, count]:
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stack.add_child(line)
		# Centered on the label point; a name wider than its region spills over, kept on the map.
		var stack_size := stack.get_combined_minimum_size()
		var at := _to_screen(region_data["label_point"]) - stack_size * 0.5
		at.x = clampf(at.x, 4.0, size.x - stack_size.x - 4.0)
		stack.position = at - bounds.position
		button.add_child(stack)

## A region: its cities are the buttons. Cities that can be fought place their names first, so
## a safe city's name gives way.
func _rebuild_cities() -> void:
	_clear_layer()
	var members: Array = WorldMap.region(_region_id).get("cities", [])
	var placed: Array[Rect2] = []
	var ordered: Array[Dictionary] = []
	for entry in _entries:
		if entry.get("id", "") in members:
			ordered.append(entry)
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
	var text_color := COLOR_TEXT
	if state == WorldMap.STATE_SAFE:
		text_color = Color("6b7a94")
	elif state == WorldMap.STATE_CONSUMED:
		text_color = Color("8b7fa3")
	if city_id == _home_id:
		text_color = STATE_COLORS[WorldMap.STATE_THREATENED]
	var label := _outlined(String(entry.get("name", "")), 16, text_color)
	var label_size := label.get_minimum_size()
	var label_rect := _place_label(center, label_size, placed)
	var marker := Rect2(center - Vector2(14, 14), Vector2(28, 28))
	label.visible = label_rect.size.x > 0.0
	if label.visible:
		placed.append(label_rect)
	else:
		label_rect = marker
	var bounds := marker.merge(label_rect).grow(4.0)
	var button := _map_button(StringName("world_city_%s" % city_id), bounds, city_id == _selected_id, 0.0)
	button.modulate = Color(1, 1, 1, 1.0 if _matches(entry) else 0.25)
	label.position = label_rect.position - bounds.position
	button.add_child(label)

## A transparent button over the map that lights on hover; border_alpha outlines it at rest.
func _map_button(action: StringName, bounds: Rect2, primary: bool, border_alpha: float) -> Button:
	var button := Button.new()
	button.position = bounds.position
	button.size = bounds.size
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not _interactive
	button.mouse_filter = Control.MOUSE_FILTER_STOP if _interactive else Control.MOUSE_FILTER_IGNORE
	button.set_meta(&"menu_action", action)
	button.set_meta(&"primary", primary)
	var rest: StyleBox = StyleBoxEmpty.new()
	if border_alpha > 0.0:
		rest = _hover_style(0.0, border_alpha * (2.0 if primary else 1.0))
	for state_name in ["normal", "disabled", "focus"]:
		button.add_theme_stylebox_override(state_name, rest)
	button.add_theme_stylebox_override("hover", _hover_style(0.10, 0.6))
	button.add_theme_stylebox_override("pressed", _hover_style(0.22, 0.6))
	button.add_theme_stylebox_override("hover_pressed", _hover_style(0.22, 0.6))
	_layer.add_child(button)
	button.pressed.connect(func() -> void: action_pressed.emit(action))
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			hovered.emit()
	)
	return button

func _outlined(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", COLOR_OCEAN)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _hover_style(alpha: float, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_SELECT, alpha * 0.6)
	style.border_color = Color(COLOR_SELECT, border_alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style

# --- Drawing --------------------------------------------------------------------------------

func _draw() -> void:
	var map := Rect2(_to_screen(Vector2.ZERO), WorldMap.world_box().size * _xform.get_scale())
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_OCEAN)
	# Equator and tropics-ish guide lines, and the prime meridian.
	for lat in [0.0, 45.0, -45.0]:
		var y := _to_screen(WorldMap.project(0.0, lat)).y
		draw_line(Vector2(map.position.x, y), Vector2(map.end.x, y), COLOR_GRID, 1.0)
	var x0 := _to_screen(WorldMap.project(0.0, 0.0)).x
	draw_line(Vector2(x0, map.position.y), Vector2(x0, map.end.y), COLOR_GRID, 1.0)
	# https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-method-draw-mesh
	draw_mesh(_land, null, _xform, COLOR_LAND)
	for outline in _outlines:
		draw_polyline(_to_screen_polygon(outline), COLOR_COAST, 1.0, true)
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

## Diagonal lines over a polygon, kept to the part of it on screen.
func _hatch(polygon: PackedVector2Array) -> void:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	bounds = bounds.intersection(Rect2(Vector2.ZERO, size))
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
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
	# Opening: a lock-on ring closes on the city and its name stays up while the view closes in.
	if city_id == _focus_city_id:
		var e := _t * _t * (3.0 - 2.0 * _t)
		draw_arc(center, lerpf(40.0, 14.0, e), 0.0, TAU, 48, Color(COLOR_SELECT, 0.25 + 0.6 * e), 2.0, true)
		var font := get_theme_default_font()
		var text := String(entry.get("name", "")).to_upper()
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var at := center + Vector2(-width * 0.5, 44.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, COLOR_OCEAN)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, COLOR_TEXT)
