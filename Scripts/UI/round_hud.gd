extends Node3D

## The ERM wrist display: one holographic panel projected just above the left bracer and
## tilted toward the eyes, so it sits below the line of sight instead of floating in it.
##
## Read top to bottom (top is toward the fingers): Chen's comms caption, mission and time,
## life force, one pip per rift showing how close it is to sealing, then score and combo.
## It is drawn in 2D into a small viewport that only re-renders when something changes,
## at most 30 times a second.

@export var round_controller_path: NodePath
## Where the panel floats, in the left controller's space (the bracer runs along +Z).
@export var mount_offset: Vector3 = Vector3(0.008, 0.088, 0.175)
## How far the panel leans back from upright toward the eyes.
@export var tilt_degrees: float = 53.0
@export var panel_width: float = 0.115

const CANVAS := Vector2i(440, 384)
## The comms caption row across the top; everything else draws below it.
const CAPTION_ROW := 64.0
const CYAN := Color(0.1, 0.72, 1.0)
const INK := Color(0.89, 0.92, 0.97)
const MUTED := Color(0.55, 0.61, 0.72)
const DIM := Color(0.1, 0.14, 0.22)
const GOLD := Color(1.0, 0.78, 0.08)
const VIOLET := Color(0.62, 0.35, 1.0)
const RED := Color(1.0, 0.25, 0.3)
const BOSS := Color(0.95, 0.16, 0.36)
const LIFE_COLORS := {
	&"healthy": Color(0.25, 0.65, 1.0),
	&"caution": Color(0.55, 0.35, 0.95),
	&"danger": Color(0.95, 0.35, 0.55),
	&"critical": Color(0.95, 0.15, 0.15),
	&"depleted": Color(0.95, 0.15, 0.15),
}
const LIFE_SEGMENTS := 20
const REDRAW_INTERVAL := 1.0 / 30.0

var _viewport: SubViewport
var _canvas: Control
var _font: Font
var _bold: Font
var _dirty: bool = true
var _since_redraw: float = 0.0
var _time: float = 0.0

var _in_mission: bool = false
var _status: String = ""
var _elapsed: float = 0.0
var _score: int = 0
var _delta: int = 0
var _delta_age: float = 99.0
var _multiplier: float = 1.0
var _combo_left: float = 0.0
var _combo_timeout: float = 4.0
var _life: float = 100.0
var _life_max: float = 100.0
var _life_state: StringName = &"healthy"
## One entry per rift in the mission: {state: &"pending"/&"open"/&"sealed", progress: 0..1}.
var _rifts: Array[Dictionary] = []
var _rift_slot: Dictionary = {}
## In a boss fight one rift hex shows the boss's anchor instead, under the boss's name.
var _boss_name: String = ""
var _boss_slot: int = -1
var _caption: String = ""
var _caption_speaker: String = ""
var _caption_left: float = 0.0

func _ready() -> void:
	transform = Transform3D(Basis.from_euler(Vector3(-deg_to_rad(tilt_degrees), 0.0, 0.0)), mount_offset)
	_font = ThemeDB.fallback_font
	var heavy := FontVariation.new()
	heavy.base_font = _font
	heavy.variation_embolden = 0.7
	_bold = heavy
	_build_panel()
	await get_tree().process_frame
	_connect_round()
	_connect_life()
	_connect_rifts()
	_connect_comms()
	_connect_boss()
	_mark_dirty()

func _process(delta: float) -> void:
	_time += delta
	var animating := false
	if _combo_left > 0.0:
		_combo_left = maxf(_combo_left - delta, 0.0)
		animating = true
	if _caption_left > 0.0:
		_caption_left = maxf(_caption_left - delta, 0.0)
		animating = true
		if _caption_left <= 0.0:
			_mark_dirty()
	if _delta_age < 0.8:
		_delta_age += delta
		animating = true
	if _life_state == &"critical" or _has_open_rift():
		animating = true
	_since_redraw += delta
	if (_dirty or animating) and _since_redraw >= REDRAW_INTERVAL:
		_since_redraw = 0.0
		_dirty = false
		_canvas.queue_redraw()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _mark_dirty() -> void:
	_dirty = true

# --- Wiring -----------------------------------------------------------------

func _connect_round() -> void:
	var controller := get_node_or_null(round_controller_path) as RoundController
	if controller == null:
		controller = get_tree().get_first_node_in_group("RoundController") as RoundController
	if controller == null:
		return
	_combo_timeout = controller.combo_timeout
	controller.score_changed.connect(_on_score_changed)
	controller.rift_progress_changed.connect(_on_progress_changed)
	controller.mission_status_changed.connect(_on_mission_status)
	controller.combo_changed.connect(_on_combo_changed)
	controller.time_changed.connect(_on_time_changed)
	controller.round_finished.connect(_on_round_finished)

func _connect_life() -> void:
	var manager := get_tree().get_first_node_in_group("LifeForceManager")
	if manager == null:
		return
	manager.life_force_changed.connect(_on_life_changed)
	manager.life_force_state_changed.connect(_on_life_state_changed)
	_on_life_changed(manager.current_life_force, manager.max_life_force)
	_on_life_state_changed(manager.get_state_name())

func _connect_rifts() -> void:
	var director := get_tree().get_first_node_in_group("RiftSpawnManager")
	if director == null:
		return
	director.rift_spawned.connect(_on_rift_spawned)
	director.rift_closed.connect(_on_rift_closed)

func _connect_comms() -> void:
	var comms := get_tree().get_first_node_in_group("ChenComms")
	if comms:
		comms.line_started.connect(_on_comms_line)
		if comms.has_signal("line_cut"):
			comms.line_cut.connect(_on_comms_cut)

func _connect_boss() -> void:
	var boss := get_tree().get_first_node_in_group("MawBoss")
	if boss:
		boss.phase_two_started.connect(_on_boss_phase_two)

## The rift hex becomes the anchor and takes the boss's name. It drains as the boss weakens.
func _on_boss_phase_two(boss_name: String, rift_id: int) -> void:
	_boss_name = boss_name
	_boss_slot = _rift_slot.get(rift_id, -1)
	_mark_dirty()

func _on_comms_cut() -> void:
	# The cut-off words hang for a moment, then go.
	_caption_left = minf(_caption_left, 0.6)
	_mark_dirty()

func _on_comms_line(speaker: String, text: String, seconds: float) -> void:
	_caption_speaker = speaker
	_caption = text
	_caption_left = seconds + 0.8
	_mark_dirty()

func _on_score_changed(total: int, delta: int, reason: StringName) -> void:
	if reason == &"reset":
		_in_mission = true
		_delta_age = 99.0
	elif delta > 0:
		_delta = delta
		_delta_age = 0.0
	_score = total
	_mark_dirty()

func _on_progress_changed(closed: int, total: int) -> void:
	if closed == 0 or _rifts.size() != total:
		_rifts.clear()
		_rift_slot.clear()
		_boss_name = ""
		_boss_slot = -1
		for _i in total:
			_rifts.append({"state": &"pending", "progress": 0.0})
	for i in mini(closed, _rifts.size()):
		_rifts[i]["state"] = &"sealed"
	_mark_dirty()

func _on_mission_status(text: String) -> void:
	# "OP-03  2/3  •  CHEN'S GAMBIT": the wrist keeps the code and count. The pips show the rest.
	_status = text.get_slice("•", 0).strip_edges()
	_mark_dirty()

func _on_combo_changed(_streak: int, multiplier: float) -> void:
	_multiplier = multiplier
	_combo_left = _combo_timeout if multiplier > 1.0 else 0.0
	_mark_dirty()

func _on_time_changed(seconds: float) -> void:
	var before := floori(_elapsed)
	_elapsed = seconds
	if floori(seconds) != before:
		_mark_dirty()

func _on_round_finished(_outcome: StringName, _final_score: int) -> void:
	_in_mission = false
	_combo_left = 0.0
	_mark_dirty()

func _on_life_changed(current: float, maximum: float) -> void:
	_life = current
	_life_max = maxf(maximum, 1.0)
	_mark_dirty()

func _on_life_state_changed(state: StringName) -> void:
	_life_state = state
	_mark_dirty()

func _on_rift_spawned(rift_id: int, rift: Node3D) -> void:
	for i in _rifts.size():
		if _rifts[i]["state"] == &"pending":
			_rifts[i]["state"] = &"open"
			_rift_slot[rift_id] = i
			break
	if rift and rift.has_signal("health_changed"):
		rift.health_changed.connect(_on_rift_health.bind(rift_id))
	_mark_dirty()

func _on_rift_health(current: int, maximum: int, rift_id: int) -> void:
	var slot: int = _rift_slot.get(rift_id, -1)
	if slot >= 0:
		_rifts[slot]["progress"] = 1.0 - clampf(float(current) / maxf(float(maximum), 1.0), 0.0, 1.0)
		_mark_dirty()

func _on_rift_closed(rift_id: int, _closed_count: int, _total: int) -> void:
	var slot: int = _rift_slot.get(rift_id, -1)
	if slot >= 0:
		_rifts[slot]["state"] = &"sealed"
		_rifts[slot]["progress"] = 1.0
		_mark_dirty()

func _has_open_rift() -> bool:
	for rift in _rifts:
		if rift["state"] == &"open":
			return true
	return false

# --- The panel ----------------------------------------------------------------

func _build_panel() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "Display"
	_viewport.size = CANVAS
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_canvas = Control.new()
	_canvas.size = Vector2(CANVAS)
	_canvas.draw.connect(_draw_panel)
	_viewport.add_child(_canvas)

	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	var quad := QuadMesh.new()
	quad.size = Vector2(panel_width, panel_width * float(CANVAS.y) / float(CANVAS.x))
	screen.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_fog = true
	material.albedo_texture = _viewport.get_texture()
	material.render_priority = 2
	screen.material_override = material
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(screen)

	# A soft projector glow under the panel, where it leaves the bracer.
	var glow := GlowSprite.create(CYAN, 0.09, 0.35)
	glow.name = "ProjectorGlow"
	glow.position = Vector3(0.0, -0.045, -0.012)
	add_child(glow)

func _draw_panel() -> void:
	var c := _canvas
	var w := float(CANVAS.x)
	var h := float(CANVAS.y)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.015, 0.03, 0.07, 0.92)
	frame.border_color = Color(CYAN, 0.45)
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(16)
	c.draw_style_box(frame, Rect2(2.0, 2.0, w - 4.0, h - 4.0))
	for y in range(8, int(h) - 8, 4):
		c.draw_line(Vector2(10.0, y), Vector2(w - 10.0, y), Color(CYAN, 0.03), 1.0)
	_draw_brackets(c, w, h)
	_draw_caption(c, w)
	c.draw_set_transform(Vector2(0.0, CAPTION_ROW))

	if not _in_mission:
		_text(c, "ERM // STANDBY", Vector2(24.0, 58.0), 30, CYAN, _bold)
		_text(c, "Gauntlets online", Vector2(24.0, 96.0), 24, MUTED)
		_draw_life(c, 150.0)
		return

	# Mission and time.
	_text(c, _status if _status != "" else "STAND BY", Vector2(24.0, 52.0), 24, MUTED, _font, 280.0)
	var whole := maxi(floori(_elapsed), 0)
	_text_right(c, "%d:%02d" % [whole / 60, whole % 60], Vector2(w - 24.0, 58.0), 46, INK, _bold)
	c.draw_line(Vector2(24.0, 74.0), Vector2(w - 24.0, 74.0), Color(CYAN, 0.25), 2.0)

	_draw_life(c, 92.0)
	_draw_rifts(c, 170.0)

	# Score, the last award rising off it, and the combo with its countdown.
	_text(c, "%06d" % _score, Vector2(24.0, 292.0), 56, INK, _bold)
	if _delta_age < 0.8:
		var rise := _delta_age / 0.8
		_text(c, "+%d" % _delta, Vector2(214.0, 262.0 - rise * 22.0), 26, Color(GOLD, 1.0 - rise), _bold)
	if _multiplier > 1.0:
		var chip := Rect2(w - 132.0, 238.0, 108.0, 56.0)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(GOLD, 0.16)
		box.border_color = GOLD
		box.set_border_width_all(2)
		box.set_corner_radius_all(10)
		c.draw_style_box(box, chip)
		_text_right(c, "×%.1f" % _multiplier, Vector2(chip.end.x - 14.0, chip.position.y + 41.0), 34, GOLD, _bold)
		var left := clampf(_combo_left / maxf(_combo_timeout, 0.01), 0.0, 1.0)
		c.draw_rect(Rect2(chip.position.x, chip.end.y + 6.0, chip.size.x * left, 5.0), GOLD)
	else:
		_text_right(c, "×1.0", Vector2(w - 24.0, 286.0), 30, MUTED)

## Chen's line while she speaks, with a pulsing comms light; a dim COMMS label otherwise.
func _draw_caption(c: Control, w: float) -> void:
	var speaking := _caption_left > 0.0
	var light := Color(CYAN, 0.4 + 0.6 * absf(sin(_time * 7.0))) if speaking else Color(MUTED, 0.35)
	c.draw_circle(Vector2(32.0, 36.0), 6.0, light)
	if not speaking:
		_text(c, "COMMS", Vector2(48.0, 43.0), 20, Color(MUTED, 0.6))
	else:
		var label := _caption_speaker + "  "
		var label_width := _bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20).x
		_text(c, label, Vector2(48.0, 34.0), 20, CYAN, _bold)
		var lines := _wrap(_caption, w - 72.0 - label_width, w - 72.0, 22)
		_text(c, lines[0], Vector2(48.0 + label_width, 34.0), 22, INK)
		if lines.size() > 1:
			_text(c, lines[1], Vector2(48.0, 58.0), 22, INK)
	c.draw_line(Vector2(24.0, CAPTION_ROW - 1.0), Vector2(w - 24.0, CAPTION_ROW - 1.0), Color(CYAN, 0.25), 2.0)

## Splits a caption into at most two lines: the first narrower to leave room for the speaker.
func _wrap(text: String, first_width: float, width: float, size: int) -> Array[String]:
	var lines: Array[String] = [""]
	for word in text.split(" ", false):
		var limit := first_width if lines.size() == 1 else width
		var trial := word if lines[-1] == "" else lines[-1] + " " + word
		if _font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x <= limit or lines[-1] == "":
			lines[-1] = trial
		elif lines.size() < 2:
			lines.append(word)
		else:
			lines[-1] += "…"
			break
	return lines

func _draw_life(c: Control, top: float) -> void:
	var w := float(CANVAS.x)
	var color: Color = LIFE_COLORS.get(_life_state, CYAN)
	var ratio := clampf(_life / _life_max, 0.0, 1.0)
	if _life_state == &"critical":
		color = Color(color, 0.55 + 0.45 * absf(sin(_time * 5.5)))
	_text(c, "LIFE FORCE", Vector2(24.0, top + 22.0), 22, MUTED)
	_text_right(c, "%d" % roundi(_life), Vector2(w - 24.0, top + 28.0), 36, color, _bold)
	var left := 24.0
	var span := w - 48.0
	var gap := 4.0
	var segment := (span - gap * (LIFE_SEGMENTS - 1)) / LIFE_SEGMENTS
	var lit := ceili(ratio * LIFE_SEGMENTS - 0.001)
	for i in LIFE_SEGMENTS:
		var rect := Rect2(left + i * (segment + gap), top + 40.0, segment, 22.0)
		c.draw_rect(rect, color if i < lit else DIM)

## One hexagon per rift. Sealed: solid cyan with a check. Open: a violet outline filling
## from the center as the rift weakens. Not yet open: a dim outline. Past eight rifts the
## row folds into two offset rows, like a honeycomb, so the hexes stay readable.
func _draw_rifts(c: Control, top: float) -> void:
	if _boss_name != "":
		_text(c, _boss_name, Vector2(24.0, top + 22.0), 18, BOSS, _bold, 96.0)
	else:
		_text(c, "RIFTS", Vector2(24.0, top + 22.0), 22, MUTED)
	var rows := 2 if _rifts.size() > 8 else 1
	var per_row := maxi(ceili(float(_rifts.size()) / rows), 1)
	var spacing := minf(60.0, (float(CANVAS.x) - 140.0) / (per_row + (0.5 if rows > 1 else 0.0)))
	var radius := minf(22.0, spacing * 0.56)
	for i in _rifts.size():
		var row := i / per_row
		var center := Vector2(128.0 + (i % per_row + row * 0.5) * spacing, top + 14.0 + row * radius * 1.55)
		var rift: Dictionary = _rifts[i]
		if i == _boss_slot and rift["state"] == &"open":
			# The anchor: a solid hex that shrinks as the boss loses its hold.
			var anchor := 1.0 - float(rift["progress"])
			var throb := 0.7 + 0.3 * absf(sin(_time * 2.2))
			if anchor > 0.02:
				c.draw_colored_polygon(_hexagon(center, radius * clampf(anchor, 0.15, 1.0)), Color(BOSS, 0.9))
			c.draw_polyline(_hexagon(center, radius, true), Color(BOSS, throb), 3.0)
			continue
		match rift["state"]:
			&"sealed":
				c.draw_colored_polygon(_hexagon(center, radius), CYAN)
				c.draw_polyline(PackedVector2Array([center + Vector2(-9, 0), center + Vector2(-2, 8), center + Vector2(10, -8)]), Color(0.02, 0.04, 0.09), 4.0)
			&"open":
				var pulse := 0.6 + 0.4 * absf(sin(_time * 3.0))
				var progress: float = rift["progress"]
				if progress > 0.02:
					c.draw_colored_polygon(_hexagon(center, radius * clampf(progress, 0.15, 1.0)), Color(VIOLET, 0.85))
				c.draw_polyline(_hexagon(center, radius, true), Color(VIOLET, pulse), 3.0)
			_:
				c.draw_polyline(_hexagon(center, radius, true), DIM.lightened(0.15), 2.0)

func _hexagon(center: Vector2, radius: float, closed := false) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in (7 if closed else 6):
		var a := PI / 6.0 + TAU * float(k) / 6.0
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return points

func _draw_brackets(c: Control, w: float, h: float) -> void:
	var arm := 22.0
	var inset := 10.0
	for corner in [Vector2(inset, inset), Vector2(w - inset, inset), Vector2(inset, h - inset), Vector2(w - inset, h - inset)]:
		var sx := 1.0 if corner.x < w * 0.5 else -1.0
		var sy := 1.0 if corner.y < h * 0.5 else -1.0
		c.draw_polyline(PackedVector2Array([corner + Vector2(0.0, sy * arm), corner, corner + Vector2(sx * arm, 0.0)]), CYAN, 3.0)

func _text(c: Control, text: String, at: Vector2, size: int, color: Color, font: Font = null, max_width: float = -1.0) -> void:
	c.draw_string(font if font else _font, at, text, HORIZONTAL_ALIGNMENT_LEFT, max_width, size, color)

func _text_right(c: Control, text: String, right_edge: Vector2, size: int, color: Color, font: Font = null) -> void:
	var f := font if font else _font
	var width := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	c.draw_string(f, right_edge - Vector2(width, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
