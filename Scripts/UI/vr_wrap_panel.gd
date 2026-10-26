extends VRMenuPanel
class_name VRWrapPanel

## One of the three panels that wrap around the player on the city map and results: the city's
## progress on the left, the map in the middle, the chosen site and Deploy on the right. Plain
## panels with an accent bar; the buttons, labels, and sounds are VRMenuPanel's.

## Viewport pixel sizes of the middle panel and of each side panel.
const CENTER_PIXELS := Vector2i(640, 620)
const SIDE_PIXELS := Vector2i(320, 620)
const CITY_NAME := "DEAD CITY"
const COLOR_EDGE := Color("2a3a66")
const COLOR_WRAP_PANEL := Color("0a1022")
const COLOR_DARK_TEXT := Color("031319")
const SHORT_TIER_LABELS := {DifficultyTier.FULL_RESONANCE: "FULL RES."}

var _accent_bar: ColorRect
var _margin: MarginContainer

func _build_shell() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = COLOR_WRAP_PANEL
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var edge := Panel.new()
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge.add_theme_stylebox_override("panel", _style_box(Color(0, 0, 0, 0), COLOR_EDGE, 2, 0))
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)
	_accent_bar = ColorRect.new()
	_accent_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_accent_bar.custom_minimum_size.y = 5
	_accent_bar.offset_bottom = 5
	_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_accent_bar)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_margin.add_child(_content)

func _begin_wrap(accent: Color, margin: int = 18) -> void:
	_clear_content()
	_accent_bar.color = accent
	_margin.add_theme_constant_override("margin_left", margin)
	_margin.add_theme_constant_override("margin_right", margin)
	_margin.add_theme_constant_override("margin_top", margin + 5)
	_margin.add_theme_constant_override("margin_bottom", margin)
	_content.add_theme_constant_override("separation", 0 if margin == 0 else 10)

# --- City map: left -------------------------------------------------------------------------

## The city's progress, a new recruit's nudge toward training, then Training and Settings.
func show_city_status(entries: Array[Dictionary], training_first: bool = false) -> void:
	_begin_wrap(COLOR_GREEN)
	var sealed := CityMap.sealed_count(entries)
	_content.add_child(_label("BREACH ZONE", 16, COLOR_MUTED, true))
	_content.add_child(_label(CITY_NAME, 32, COLOR_TEXT, true))
	_content.add_child(_percent_row(-1, sealed, entries.size()))
	_content.add_child(_sealed_bar(entries, ""))
	var next := _first_live(entries)
	var progress := "%d of %d sites sealed." % [sealed, entries.size()]
	if not next.is_empty():
		progress += " Seal %s to push the line." % next.get("title", "")
	elif sealed >= entries.size():
		progress += " The city is reclaimed."
	_content.add_child(_wrapped(progress, 17, COLOR_MUTED))
	_content.add_child(_divider())
	if training_first:
		_content.add_child(_label("NEW RECRUIT", 20, COLOR_TEXT, true))
		_content.add_child(_wrapped("Start with Dr. Chen's training chamber. About five minutes.", 17, COLOR_MUTED))
	_content.add_child(_spacer())
	var training := _make_action_button(
		&"training",
		"◈  TRAINING CHAMBER\n%s" % ("Recommended first" if training_first else "Replay the walkthrough"),
		COLOR_VIOLET,
		Vector2(0, 70),
		training_first
	)
	_compact_menu_button(training, 70.0)
	_content.add_child(training)
	var world := _make_action_button(&"world", "◎  WORLD MAP", COLOR_MAGENTA, Vector2(0, 60))
	var settings := _make_action_button(&"settings", "⌁  SETTINGS", COLOR_BLUE, Vector2(0, 60))
	for button in [world, settings]:
		_compact_menu_button(button, 60.0)
		_tight_sides(button, 8)
	_content.add_child(_button_pair(world, settings))
	_content.add_child(_hint())

# --- City map: center -----------------------------------------------------------------------

func show_city_map(entries: Array[Dictionary], selected_id: String) -> void:
	_begin_wrap(COLOR_MAGENTA, 0)
	var header := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		header.add_theme_constant_override(side, 18)
	header.add_theme_constant_override("margin_top", 10)
	header.add_theme_constant_override("margin_bottom", 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	header.add_child(row)
	var title := _label("PICK A SITE", 18, COLOR_TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_label("● SEALED", 16, COLOR_GREEN, true))
	row.add_child(_label("● LIVE", 16, COLOR_MAGENTA, true))
	row.add_child(_label("○ BEHIND THE LINE", 16, COLOR_MUTED, true))
	_content.add_child(header)
	_content.add_child(_map(entries, selected_id, true))

# --- City map: right ------------------------------------------------------------------------

## The chosen site, the difficulty it will play at, and Deploy in that difficulty's color.
func show_site_detail(entry: Dictionary, tier_id: String, training_first: bool = false) -> void:
	var tier := DifficultyTier.resolve(tier_id)
	var tier_color := _tier_color(tier)
	_begin_wrap(tier_color)
	var cleared: bool = entry.get("cleared", false)
	_content.add_child(_label(
		"%s  •  %s" % [entry.get("codename", ""), "SEALED" if cleared else "LIVE"],
		16,
		COLOR_GREEN if cleared else Color("ff8bdd"),
		true
	))
	var title := _wrapped(String(entry.get("title", "")), 30, COLOR_TEXT, true)
	_content.add_child(title)
	var summary := _wrapped(String(entry.get("summary", "")), 17, Color("c4d3e4"))
	summary.max_lines_visible = 3
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_content.add_child(summary)
	var meta := MissionCatalog.expected_minutes_text(entry)
	var best := float(entry.get("best_seconds", 0.0))
	if best > 0.0:
		meta += "  •  YOUR BEST %s" % _clock(best)
	_content.add_child(_label(meta, 17, COLOR_TEXT, true))
	_content.add_child(_label("DIFFICULTY", 16, COLOR_MUTED, true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for option in DifficultyTier.ORDER:
		var chosen: bool = option == tier
		var text := "%s%s\n%s" % ["● " if chosen else "", SHORT_TIER_LABELS.get(option, DifficultyTier.label(option)), _pips(option)]
		var button := _make_action_button(StringName("tier_%s" % option), text, _tier_color(option), Vector2(0, 60), chosen)
		_compact_menu_button(button, 60.0)
		button.add_theme_font_size_override("font_size", 17)
		_tight_sides(button, 8)
		grid.add_child(button)
	_content.add_child(grid)
	var blurb := _wrapped(DifficultyTier.blurb(tier), 17, tier_color)
	_content.add_child(blurb)
	_content.add_child(_spacer())
	# The time is on the meta line above; the button names only the difficulty, so it fits.
	var deploy_line := "TRAINING RECOMMENDED FIRST" if training_first else DifficultyTier.label(tier)
	if training_first:
		var deploy := _make_action_button(&"deploy", "DEPLOY\n%s" % deploy_line, tier_color, Vector2(0, 92))
		deploy.add_theme_font_size_override("font_size", 17)
		_tight_sides(deploy, 8)
		_content.add_child(deploy)
	else:
		_content.add_child(_make_solid_button(&"deploy", "DEPLOY\n%s" % deploy_line, tier_color, 92.0))

# --- Results --------------------------------------------------------------------------------
# report: outcome, score, debrief, seconds, previous_best, best_seconds, tier, mission (entry),
# sealed_before, entries (after the round), next (entry, or {}), offer_training.

## Left: what the round did to the city, and the best time at the tier it was played at.
func show_city_report(report: Dictionary) -> void:
	var victory: bool = report.get("outcome", &"") == &"victory"
	_begin_wrap(COLOR_GREEN if victory else COLOR_RED)
	var entries: Array[Dictionary] = report.get("entries", [] as Array[Dictionary])
	var before := int(report.get("sealed_before", -1))
	var after := CityMap.sealed_count(entries)
	var moved := victory and before >= 0 and after > before
	var mission: Dictionary = report.get("mission", {})
	_content.add_child(_label("BREACH ZONE  •  %s" % CITY_NAME, 16, COLOR_MUTED, true))
	_content.add_child(_percent_row(before if moved else -1, after, entries.size()))
	_content.add_child(_sealed_bar(entries, String(mission.get("id", "")) if moved else ""))
	var headline := "THE LINE MOVED" if moved else ("THE LINE HELD" if victory else "THE BREACH HELD")
	_content.add_child(_label(headline, 26, COLOR_GREEN if moved else (COLOR_TEXT if victory else COLOR_RED), true))
	var body := ""
	var next: Dictionary = report.get("next", {})
	if moved:
		body = "%s is sealed." % mission.get("title", "The site")
		if not next.is_empty() and not next.get("cleared", false):
			body += " %s is now live." % next.get("title", "")
		elif after >= entries.size():
			body += " The city is reclaimed."
	elif victory:
		body = "This site was already sealed. Your time still counts."
	else:
		body = "Life force depleted. The front did not move."
	_content.add_child(_wrapped(body, 17, COLOR_MUTED))
	_content.add_child(_divider())
	var best := float(report.get("best_seconds", 0.0))
	if best > 0.0:
		_content.add_child(_label("YOUR BEST AT %s" % DifficultyTier.label(String(report.get("tier", ""))), 16, COLOR_MUTED, true))
		_content.add_child(_label(_clock(best), 34, COLOR_TEXT, true))
	_content.add_child(_spacer())
	_content.add_child(_hint())

## Center: the outcome, time and score over the map, with the front where it moved to.
func show_results_map(report: Dictionary) -> void:
	var victory: bool = report.get("outcome", &"") == &"victory"
	var accent := COLOR_GREEN if victory else COLOR_RED
	_begin_wrap(accent, 0)
	var header := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		header.add_theme_constant_override(side, 20)
	header.add_theme_constant_override("margin_top", 12)
	header.add_theme_constant_override("margin_bottom", 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	header.add_child(row)
	var outcome := VBoxContainer.new()
	outcome.add_theme_constant_override("separation", 2)
	outcome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var subtitle := "ALL RIFTS SEALED" if victory else "LIFE FORCE DEPLETED"
	var tier_label := DifficultyTier.label(String(report.get("tier", ""))) if report.has("tier") else ""
	if tier_label != "":
		subtitle += "  •  %s" % tier_label
	outcome.add_child(_label(subtitle, 16, accent, true))
	outcome.add_child(_label("MISSION COMPLETE" if victory else "OPERATION ENDED", 30, COLOR_TEXT, true))
	row.add_child(outcome)
	var seconds := float(report.get("seconds", 0.0))
	if victory and seconds > 0.0:
		var time_stack := VBoxContainer.new()
		time_stack.add_theme_constant_override("separation", 0)
		var time_label := _label(_clock(seconds), 40, COLOR_TEXT, true)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		time_stack.add_child(time_label)
		var previous := float(report.get("previous_best", 0.0))
		var note := _label("NEW BEST TIME" if previous > 0.0 and seconds < previous else "SEALED IN", 16, COLOR_GREEN if previous > 0.0 and seconds < previous else COLOR_MUTED, true)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		time_stack.add_child(note)
		row.add_child(time_stack)
	var score_stack := VBoxContainer.new()
	score_stack.add_theme_constant_override("separation", 0)
	var score_label := _label(_grouped(int(report.get("score", 0))), 28, accent, true)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_stack.add_child(score_label)
	var score_note := _label("SCORE", 16, COLOR_MUTED, true)
	score_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_stack.add_child(score_note)
	row.add_child(score_stack)
	_content.add_child(header)
	var entries: Array[Dictionary] = report.get("entries", [] as Array[Dictionary])
	var mission_id := String((report.get("mission", {}) as Dictionary).get("id", ""))
	var before := int(report.get("sealed_before", -1))
	var moved := victory and before >= 0 and CityMap.sealed_count(entries) > before
	_content.add_child(_map(entries, "", false, before if moved else -1, mission_id if moved else ""))
	var debrief := String(report.get("debrief", ""))
	if debrief != "":
		var strip := MarginContainer.new()
		for side in ["margin_left", "margin_right"]:
			strip.add_theme_constant_override(side, 20)
		strip.add_theme_constant_override("margin_top", 10)
		strip.add_theme_constant_override("margin_bottom", 12)
		var line := _wrapped(debrief, 17, COLOR_TEXT)
		# https://docs.godotengine.org/en/stable/classes/class_label.html#class-label-property-max-lines-visible
		line.max_lines_visible = 2
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		strip.add_child(line)
		_content.add_child(strip)

## Right: the next site and Deploy after a clear that unlocks one; otherwise Retry leads.
## Retry and Next keep the tier the round was played at.
func show_results_actions(report: Dictionary) -> void:
	var victory: bool = report.get("outcome", &"") == &"victory"
	var tier := String(report.get("tier", DifficultyTier.STANDARD))
	var next: Dictionary = report.get("next", {})
	var mission: Dictionary = report.get("mission", {})
	var shown := next if victory and not next.is_empty() else mission
	_begin_wrap(_tier_color(tier))
	var eyebrow := "TRY AGAIN"
	if victory and not next.is_empty():
		eyebrow = "NEXT  •  SEALED" if next.get("cleared", false) else "NEXT  •  NOW LIVE"
	elif victory:
		eyebrow = "GO AGAIN"
	_content.add_child(_label(eyebrow, 16, Color("ff8bdd") if eyebrow.ends_with("LIVE") else COLOR_MUTED, true))
	_content.add_child(_wrapped(String(shown.get("title", "")), 30, COLOR_TEXT, true))
	var summary := _wrapped(String(shown.get("summary", "")), 17, Color("c4d3e4"))
	summary.max_lines_visible = 3
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_content.add_child(summary)
	var minutes := MissionCatalog.expected_minutes_text(shown)
	_content.add_child(_label("%s  •  %s" % [minutes, DifficultyTier.label(tier)] if minutes != "" else DifficultyTier.label(tier), 17, COLOR_TEXT, true))
	_content.add_child(_spacer())
	var tier_color := _tier_color(tier)
	var line := DifficultyTier.label(tier)
	if victory and not next.is_empty():
		_content.add_child(_make_solid_button(&"next_mission", "DEPLOY\n%s" % line, tier_color, 92.0))
		var retry := _make_action_button(&"retry", "RETRY", COLOR_CYAN, Vector2(0, 60))
		var city := _make_action_button(&"results_menu", "CITY MAP", COLOR_BLUE, Vector2(0, 60))
		_tight_sides(retry, 8)
		_tight_sides(city, 8)
		_content.add_child(_button_pair(retry, city))
	else:
		_content.add_child(_make_solid_button(&"retry", "RETRY\n%s" % line, tier_color, 92.0))
		if report.get("offer_training", false):
			_content.add_child(_make_action_button(&"results_training", "◈  REVIEW TRAINING", COLOR_VIOLET, Vector2(0, 60)))
		_content.add_child(_make_action_button(&"results_menu", "CITY MAP", COLOR_BLUE, Vector2(0, 60)))

# --- Pieces ---------------------------------------------------------------------------------

func _map(entries: Array[Dictionary], selected_id: String, interactive: bool, sealed_before: int = -1, highlight_id: String = "") -> CityMap:
	var map := CityMap.new()
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.site_pressed.connect(_on_action_pressed)
	map.site_hovered.connect(_on_button_hovered.bind(null))
	map.show_sites(entries, selected_id, interactive, sealed_before, highlight_id)
	return map

## The primary action, filled with its accent so it reads first from across the room.
func _make_solid_button(action: StringName, text: String, accent: Color, height: float) -> Button:
	var button := _make_action_button(action, text, accent, Vector2(0, height), true)
	button.add_theme_font_size_override("font_size", 24)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, COLOR_DARK_TEXT)
	button.add_theme_stylebox_override("normal", _style_box(accent, accent, 2, 8))
	button.add_theme_stylebox_override("hover", _style_box(accent.lightened(0.25), Color.WHITE, 3, 8, 10))
	button.add_theme_stylebox_override("pressed", _style_box(accent.lightened(0.45), Color.WHITE, 3, 8))
	return button

func _button_pair(first: Button, second: Button) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(first)
	row.add_child(second)
	return row

func _tight_sides(button: Button, side: int) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state) as StyleBoxFlat
		if style == null:
			continue
		var tight := style.duplicate() as StyleBoxFlat
		tight.content_margin_left = side
		tight.content_margin_right = side
		button.add_theme_stylebox_override(state, tight)

## "50% RECLAIMED", with "UP FROM 33%" above it when the round moved it.
func _percent_row(before: int, after: int, total: int) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	if before >= 0:
		stack.add_child(_label("UP FROM %d%%" % _percent(before, total), 17, COLOR_MUTED, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_label("%d%%" % _percent(after, total), 44, COLOR_GREEN, true))
	var word := _label("RECLAIMED", 18, Color("c4d3e4"), true)
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(word)
	stack.add_child(row)
	return stack

## One segment per site: sealed filled, the live one outlined, the one just sealed ringed white.
func _sealed_bar(entries: Array[Dictionary], just_sealed: String) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	for entry in entries:
		var segment := Panel.new()
		segment.custom_minimum_size.y = 12
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cleared: bool = entry.get("cleared", false)
		var live: bool = entry.get("unlocked", false) and not cleared
		var fill := COLOR_GREEN if cleared else Color("1c2a4a")
		var edge := Color.WHITE if entry.get("id", "") == just_sealed else (COLOR_MAGENTA if live else fill)
		var style := _style_box(fill, edge, 2, 0)
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		segment.add_theme_stylebox_override("panel", style)
		bar.add_child(segment)
	return bar

func _first_live(entries: Array[Dictionary]) -> Dictionary:
	for entry in entries:
		if entry.get("unlocked", false) and not entry.get("cleared", false):
			return entry
	return {}

func _pips(tier_id: String) -> String:
	var level := DifficultyTier.ORDER.find(tier_id) + 1
	return "●".repeat(level) + "○".repeat(DifficultyTier.ORDER.size() - level)

func _percent(sealed: int, total: int) -> int:
	if total <= 0:
		return 0
	return roundi(100.0 * sealed / total)

func _grouped(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out

func _wrapped(text: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var label := _label(text, font_size, color, bold)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	return label

func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size.y = 1
	line.color = Color("1f2b4c")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

func _hint() -> Label:
	var hint := _wrapped("POINT + TRIGGER TO SELECT  •  HOLD META TO RECENTER", 16, COLOR_MUTED, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return hint

# --- World map ------------------------------------------------------------------------------
# world: liberation (int), filter ("all"|"easy"|"medium"|"hard"), home_id, home_name,
# priority {title, body, bonus}, training_first (bool), assist (bool), region (a WorldMap region
# id, or "" for the whole world), zoom_from (a city id, or "").

const STATE_COLORS := {
	WorldMap.STATE_SAFE: Color("6b7a94"),
	WorldMap.STATE_THREATENED: Color("7fe3ff"),
	WorldMap.STATE_DANGER: Color("ffb347"),
	WorldMap.STATE_OVERRUN: Color("ff7fd0"),
	WorldMap.STATE_CONSUMED: Color("8b7fa3"),
}
const FILTERS := ["all", "easy", "medium", "hard"]

## The world map's view eased to where it was going: see show_world_map and zoom_world_to_city.
signal world_zoom_settled

var _world_view: WorldMapView

func _state_color(state: String) -> Color:
	return STATE_COLORS.get(state, COLOR_TEXT)

## Left: the war's one number, Chen's priority, the difficulty filter, Training and Settings.
func show_world_status(world: Dictionary) -> void:
	_begin_wrap(COLOR_MAGENTA)
	_content.add_child(_label("RSF // WORLD FRONT", 16, COLOR_MUTED, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_label("%d%%" % int(world.get("liberation", 0)), 44, Color("7fe3ff"), true))
	var word := _label("LIBERATED", 18, Color("c4d3e4"), true)
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(word)
	_content.add_child(row)
	var priority: Dictionary = world.get("priority", {})
	if not priority.is_empty():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style_box(Color(COLOR_MAGENTA, 0.07), COLOR_MAGENTA, 2, 8))
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 4)
		stack.add_child(_label("CHEN'S PRIORITY", 15, Color("ff8bdd"), true))
		stack.add_child(_wrapped(String(priority.get("body", "")), 17, COLOR_TEXT))
		if priority.has("bonus"):
			stack.add_child(_wrapped(String(priority.get("bonus", "")), 15, COLOR_MUTED))
		card.add_child(stack)
		_content.add_child(card)
	_content.add_child(_divider())
	_content.add_child(_label("SHOW MISSIONS", 15, COLOR_MUTED, true))
	var filter := String(world.get("filter", "all"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for option in FILTERS:
		var chosen: bool = option == filter
		var text: String = ("● " if chosen else "") + option.to_upper()
		var button := _make_action_button(StringName("world_filter_%s" % option), text, COLOR_CYAN, Vector2(0, 50), chosen)
		_compact_menu_button(button, 50.0)
		_tight_sides(button, 8)
		grid.add_child(button)
	_content.add_child(grid)
	_content.add_child(_spacer())
	var training_first: bool = world.get("training_first", false)
	var training := _make_action_button(&"training", "◈  TRAINING\n%s" % ("Start here" if training_first else "Replay"), COLOR_VIOLET, Vector2(0, 60), training_first)
	var settings := _make_action_button(&"settings", "⌁  SETTINGS", COLOR_BLUE, Vector2(0, 60))
	for button in [training, settings]:
		_compact_menu_button(button, 60.0)
		_tight_sides(button, 8)
	_content.add_child(_button_pair(training, settings))
	_content.add_child(_hint())

## Center: the drawn world with the fronts and every city. The whole world picks a region; a
## region (world["region"]) picks a city and has a way back out. The map view outlives a redraw
## of this panel, so a change of region eases instead of cutting. world["zoom_from"] is a city to
## start a new view on, for the way back from its section.
func show_world_map(entries: Array[Dictionary], selected_id: String, world: Dictionary) -> void:
	var region_id := String(world.get("region", ""))
	var view := _world_view if is_instance_valid(_world_view) and not _world_view.is_queued_for_deletion() and _world_view.get_parent() == _content else null
	if view:
		_content.remove_child(view)
	_begin_wrap(COLOR_CYAN, 0)
	var header := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		header.add_theme_constant_override(side, 18)
	header.add_theme_constant_override("margin_top", 10)
	header.add_theme_constant_override("margin_bottom", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	header.add_child(row)
	var title_text := "PICK A REGION" if region_id == "" else String(WorldMap.region(region_id).get("name", "")).to_upper()
	var title := _label(title_text, 18, COLOR_TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_label("● SAFE", 14, _state_color(WorldMap.STATE_SAFE), true))
	row.add_child(_label("● EASY", 14, _state_color(WorldMap.STATE_THREATENED), true))
	row.add_child(_label("● MEDIUM", 14, _state_color(WorldMap.STATE_DANGER), true))
	row.add_child(_label("● HARD", 14, _state_color(WorldMap.STATE_OVERRUN), true))
	row.add_child(_label("▨ CONSUMED", 14, _state_color(WorldMap.STATE_CONSUMED), true))
	_content.add_child(header)
	if view == null:
		view = WorldMapView.new()
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		view.action_pressed.connect(_on_action_pressed)
		view.hovered.connect(_on_button_hovered.bind(null))
		view.window_settled.connect(func() -> void: world_zoom_settled.emit())
		if String(world.get("zoom_from", "")) != "":
			view.start_at_city(String(world["zoom_from"]))
		_world_view = view
	_content.add_child(view)
	view.show_world(entries, selected_id, String(world.get("filter", "all")), String(world.get("home_id", "")), true, region_id)
	var foot := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		foot.add_theme_constant_override(side, 18)
	foot.add_theme_constant_override("margin_top", 6)
	foot.add_theme_constant_override("margin_bottom", 10)
	if region_id == "":
		foot.add_child(_wrapped("The magenta line is the front; the arrows show where it is pushing. Point at a region to zoom in.", 15, COLOR_MUTED))
	else:
		var foot_row := HBoxContainer.new()
		foot_row.add_theme_constant_override("separation", 14)
		var back := _make_action_button(&"world_back", "←  WHOLE WORLD", COLOR_CYAN, Vector2(200, 50))
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_compact_menu_button(back, 50.0)
		_tight_sides(back, 12)
		foot_row.add_child(back)
		var hint := _wrapped("Point at a city to read it. Open is on the right.", 15, COLOR_MUTED)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot_row.add_child(hint)
		foot.add_child(foot_row)
	_content.add_child(foot)

## Closes the map in on a city before its section opens. False when no world map is showing;
## otherwise world_zoom_settled fires when the map is there.
func zoom_world_to_city(city_id: String) -> bool:
	if not is_instance_valid(_world_view) or _world_view.is_queued_for_deletion() or _world_view.get_parent() != _content:
		return false
	_world_view.zoom_to_city(city_id)
	return true

func world_map_view() -> WorldMapView:
	return _world_view if is_instance_valid(_world_view) and not _world_view.is_queued_for_deletion() else null

## Right: the picked city and Open, or why it cannot be opened.
func show_world_city(entry: Dictionary, world: Dictionary) -> void:
	var state := String(entry.get("state", WorldMap.STATE_SAFE))
	var color := _state_color(state)
	_begin_wrap(color)
	var where := "behind the front" if state == WorldMap.STATE_CONSUMED else ("far from any front" if state == WorldMap.STATE_SAFE else "about %d km from the front" % WorldMap.kilometers(float(entry.get("distance", 0.0))))
	var eyebrow := "%s  •  %s" % [entry.get("state_label", ""), entry.get("difficulty_label", "")]
	if entry.get("id", "") == world.get("home_id", ""):
		eyebrow += "  •  HOME"
	_content.add_child(_wrapped(eyebrow, 15, color, true))
	var name_label := _wrapped(String(entry.get("name", "")), 30, COLOR_TEXT, true)
	_content.add_child(name_label)
	_content.add_child(_wrapped(where.substr(0, 1).to_upper() + where.substr(1), 15, COLOR_MUTED))
	var blurb := _wrapped(String(entry.get("blurb", "")), 16, Color("c4d3e4"))
	blurb.max_lines_visible = 2
	blurb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_content.add_child(blurb)
	var tier := WorldMap.tier_for(state, bool(world.get("assist", false)))
	_content.add_child(_facts([
		["LIBERATION", "%d%%" % int(entry.get("liberation", 0)), Color("7fe3ff")],
		["RESISTANCE", String(entry.get("resistance", "NONE")), COLOR_TEXT],
		["TIER", DifficultyTier.label(tier) if tier != "" else "NONE", _tier_color(tier) if tier != "" else COLOR_MUTED],
		["OPERATIONS", "%d of %d" % [int(entry.get("ops_done", 0)), int(entry.get("ops", 0))] if int(entry.get("ops", 0)) > 0 else "—", COLOR_TEXT],
	]))
	var asks := _wrapped(WorldMap.asks(state), 15, Color("c4d3e4"))
	asks.max_lines_visible = 2
	asks.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_content.add_child(asks)
	_content.add_child(_spacer())
	if entry.get("playable", false) and not entry.get("liberated", false):
		_content.add_child(_make_solid_button(&"world_open", "OPEN\n%s" % String(entry.get("name", "")).to_upper(), color, 92.0))
	else:
		var reason := "LIBERATED" if entry.get("liberated", false) else String(entry.get("difficulty_label", ""))
		var button := _make_action_button(&"world_open", reason, COLOR_MUTED, Vector2(0, 70))
		button.disabled = true
		_content.add_child(button)
	if entry.get("home", false):
		var campaign := _make_action_button(&"campaign", "◆  BREACH NIGHT", COLOR_AMBER, Vector2(0, 44))
		_compact_menu_button(campaign, 44.0)
		_content.add_child(campaign)

## Rows of [eyebrow, value, color]: the eyebrow at the left, the value flush right, a rule between rows.
func _facts(rows: Array) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_box(Color(0, 0, 0, 0), COLOR_EDGE, 1, 6))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	for index in rows.size():
		var row: Array = rows[index]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var eyebrow := _label(String(row[0]), 12, COLOR_MUTED, true)
		eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eyebrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(eyebrow)
		var value := _label(String(row[1]), 15, row[2], true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value)
		stack.add_child(line)
		if index < rows.size() - 1:
			stack.add_child(_divider())
	panel.add_child(stack)
	return panel

# --- City operations -----------------------------------------------------------------------
# city: entry (WorldMap.city_entries row), section (WorldMap.section), sealed (Array), selected_id,
# tier, assist (bool), node (the selected district, or {}), status ("open"|"sealed"|"locked"),
# best_seconds, expected_minutes (Array), kind_label, kind_summary.

## Left: back to the world, the city's liberation bar, the operation's three pips.
func show_operations_status(city: Dictionary) -> void:
	var entry: Dictionary = city.get("entry", {})
	var state := String(entry.get("state", WorldMap.STATE_SAFE))
	_begin_wrap(_state_color(state))
	var back := _make_action_button(&"city_world", "←  WORLD MAP", COLOR_CYAN, Vector2(0, 50))
	_compact_menu_button(back, 50.0)
	_content.add_child(back)
	_content.add_child(_label("%s  •  %s" % [entry.get("state_label", ""), entry.get("difficulty_label", "")], 15, _state_color(state), true))
	_content.add_child(_wrapped(String(entry.get("name", "")), 30, COLOR_TEXT, true))
	var liberation := int(entry.get("liberation", 0))
	_content.add_child(_label("CITY LIBERATION", 15, COLOR_MUTED, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_label("%d%%" % liberation, 40, Color("7fe3ff"), true))
	var word := _label("%s RESISTANCE" % entry.get("resistance", ""), 14, Color("c4d3e4"), true)
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(word)
	_content.add_child(row)
	var sealed: Array = city.get("sealed", [])
	var ops := int(entry.get("ops", 1))
	var pending := (sealed.size() / 3.0) * (100.0 / maxf(ops, 1))
	_content.add_child(_liberation_bar(liberation, pending))
	_content.add_child(_wrapped("The bar moves when an operation is complete: three districts along the path. The dashed part is the operation you are in.", 14, COLOR_MUTED))
	_content.add_child(_divider())
	_content.add_child(_label("THIS OPERATION", 15, COLOR_MUTED, true))
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 6)
	for index in 3:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(40, 10)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var on := index < sealed.size()
		var style := _style_box(COLOR_CYAN if on else Color("1c2342"), COLOR_CYAN if on else Color("1c2342"), 1, 5)
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		pip.add_theme_stylebox_override("panel", style)
		pips.add_child(pip)
	_content.add_child(pips)
	var note := "Pick any district on the left to start."
	if entry.get("liberated", false):
		note = "The city is liberated. Chen will call when the front turns back toward it."
	elif not sealed.is_empty():
		note = "Pick a connected district to continue. The line moves when all three are sealed."
	_content.add_child(_wrapped(note, 15, COLOR_MUTED))
	_content.add_child(_spacer())
	var settings := _make_action_button(&"settings", "⌁  SETTINGS", COLOR_BLUE, Vector2(0, 50))
	_compact_menu_button(settings, 50.0)
	_content.add_child(settings)
	_content.add_child(_hint())

func _liberation_bar(liberation: int, pending_percent: float) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size.y = 12
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := ColorRect.new()
	back.color = Color("1c2342")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(back)
	var fill := ColorRect.new()
	fill.color = COLOR_CYAN
	fill.anchor_right = clampf(liberation / 100.0, 0.0, 1.0)
	fill.anchor_bottom = 1.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fill)
	var pending := ColorRect.new()
	pending.color = Color(COLOR_CYAN, 0.45)
	pending.anchor_left = fill.anchor_right
	pending.anchor_right = clampf(fill.anchor_right + pending_percent / 100.0, 0.0, 1.0)
	pending.anchor_bottom = 1.0
	pending.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(pending)
	return bar

## Center: the section's districts as a path, the line, and the ground still held.
func show_operations_map(city: Dictionary) -> void:
	_begin_wrap(COLOR_MAGENTA, 0)
	var header := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		header.add_theme_constant_override(side, 18)
	header.add_theme_constant_override("margin_top", 10)
	header.add_theme_constant_override("margin_bottom", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	header.add_child(row)
	var sealed: Array = city.get("sealed", [])
	var title := _label("NEW GROUND" if sealed.is_empty() else "PUSHING THE LINE  •  %d OF 3" % sealed.size(), 18, COLOR_TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_label("■ SEALED", 14, COLOR_CYAN, true))
	row.add_child(_label("□ OPEN", 14, COLOR_TEXT, true))
	row.add_child(_label("▨ BEHIND THE LINE", 14, COLOR_MUTED, true))
	_content.add_child(header)
	_content.add_child(_operations_map(city.get("section", {}), sealed, String(city.get("selected_id", "")), true))

## A section's districts, pressable when interactive. See CityOperationsMap.show_section.
func _operations_map(section: Dictionary, sealed: Array, selected_id: String, interactive: bool, highlight_id: String = "", sealed_before: int = -1) -> CityOperationsMap:
	var map := CityOperationsMap.new()
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.node_pressed.connect(_on_action_pressed)
	map.node_hovered.connect(_on_button_hovered.bind(null))
	map.show_section(section, sealed, selected_id, interactive, highlight_id, sealed_before)
	return map

## Right: the picked district and Deploy at the city's tier.
func show_district_detail(city: Dictionary) -> void:
	var entry: Dictionary = city.get("entry", {})
	var node: Dictionary = city.get("node", {})
	var status := String(city.get("status", "locked"))
	var tier := String(city.get("tier", DifficultyTier.STANDARD))
	var tier_color := _tier_color(tier)
	_begin_wrap(tier_color)
	var status_label := String({"open": "OPEN", "sealed": "SEALED", "locked": "BEHIND THE LINE"}.get(status, ""))
	_content.add_child(_label("DISTRICT  •  %s" % status_label, 15, COLOR_CYAN if status != "locked" else COLOR_MUTED, true))
	_content.add_child(_wrapped(String(node.get("name", "No district")), 30, COLOR_TEXT, true))
	var summary := _wrapped(String(city.get("kind_summary", "")), 16, Color("c4d3e4"))
	summary.max_lines_visible = 3
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_content.add_child(summary)
	var best := float(city.get("best_seconds", 0.0))
	_content.add_child(_facts([
		["MISSION", String(city.get("kind_label", "")), COLOR_TEXT],
		["TIER", DifficultyTier.label(tier), tier_color],
		["EXPECTED", MissionCatalog.expected_minutes_text({"expected_minutes": city.get("expected_minutes", [])}), COLOR_TEXT],
		["YOUR BEST", _clock(best) if best > 0.0 else "—", Color("7fe3ff")],
	]))
	_content.add_child(_spacer())
	if String(entry.get("state", "")) == WorldMap.STATE_THREATENED:
		var assist: bool = city.get("assist", false)
		var assist_row := HBoxContainer.new()
		assist_row.add_theme_constant_override("separation", 8)
		var standard := _make_action_button(&"assist_off", ("● " if not assist else "") + "STANDARD", COLOR_CYAN, Vector2(0, 50), not assist)
		var assisted := _make_action_button(&"assist_on", ("● " if assist else "") + "ASSIST", COLOR_GREEN, Vector2(0, 50), assist)
		for button in [standard, assisted]:
			_compact_menu_button(button, 50.0)
			_tight_sides(button, 8)
		assist_row.add_child(standard)
		assist_row.add_child(assisted)
		_content.add_child(assist_row)
		_content.add_child(_wrapped("Assist: slower tells, lighter drain. Your load, never the city.", 14, COLOR_MUTED))
	if status == "open":
		_content.add_child(_make_solid_button(&"deploy", "DEPLOY\n%s" % DifficultyTier.label(tier), tier_color, 92.0))
	else:
		var button := _make_action_button(&"deploy", status_label, COLOR_MUTED, Vector2(0, 70))
		button.disabled = true
		_content.add_child(button)

# --- World results -------------------------------------------------------------------------
# A world mission's results are its city map with the outcome on top: the section as it stands
# now is pressable, and picking a district puts its card and Deploy on the right.
# report["world"]: entry (after), section (the one played), sealed_before (Array), sealed_after
# (Array), node, kind_label, moved (the seal counted), operation_complete (bool),
# liberation_before, liberation_after.
# report["city"]: the city map now, as show_operations_status takes it, or {} for a city with no
# missions. report["picked"]: a district was picked since the round ended.

## Left: what the round did to the city, the best time, then Replay, World, and Settings.
func show_world_report(report: Dictionary) -> void:
	var victory: bool = report.get("outcome", &"") == &"victory"
	var world: Dictionary = report.get("world", {})
	var entry: Dictionary = world.get("entry", {})
	_begin_wrap(COLOR_GREEN if victory else COLOR_RED)
	_content.add_child(_wrapped("%s  •  %s" % [entry.get("state_label", ""), entry.get("name", "")], 15, COLOR_MUTED, true))
	var before := int(world.get("liberation_before", 0))
	var after := int(world.get("liberation_after", before))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_label("%d%%" % after, 44, Color("7fe3ff"), true))
	var word := _label("LIBERATED", 18, Color("c4d3e4"), true)
	word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(word)
	_content.add_child(row)
	if after > before:
		_content.add_child(_label("UP FROM %d%%" % before, 16, COLOR_MUTED, true))
	var sealed_after: Array = world.get("sealed_after", [])
	var complete: bool = world.get("operation_complete", false)
	var moved: bool = world.get("moved", victory)
	var headline := "THE BREACH HELD"
	if complete:
		headline = "OPERATION COMPLETE"
	elif moved:
		headline = "THE LINE MOVED"
	elif victory:
		headline = "THE LINE HELD"
	var headline_color := COLOR_RED
	if victory:
		headline_color = COLOR_GREEN if moved or complete else COLOR_TEXT
	_content.add_child(_label(headline, 24, headline_color, true))
	var district := String((world.get("node", {}) as Dictionary).get("name", "The district"))
	var body := "The failsafe fired. %s held, and the line did not move." % district
	if complete:
		body = "%s sealed the operation. New ground is open on the map." % district
	elif moved:
		body = "%s is sealed. %d of 3 for this operation. Pick the next district on the map." % [district, sealed_after.size()]
	elif victory:
		body = "%s was already sealed. Your time still counts." % district
	_content.add_child(_wrapped(body, 16, COLOR_MUTED))
	_content.add_child(_divider())
	var best := float(report.get("best_seconds", 0.0))
	if best > 0.0:
		_content.add_child(_wrapped("YOUR BEST  •  %s AT %s" % [String(world.get("kind_label", "")), DifficultyTier.label(String(report.get("tier", "")))], 14, COLOR_MUTED, true))
		_content.add_child(_label(_clock(best), 34, COLOR_TEXT, true))
	_content.add_child(_spacer())
	# After a defeat Retry leads on the right; after a seal, Replay plays the district for its time.
	if victory:
		var replay := _make_action_button(&"retry", "↻  REPLAY %s" % district.to_upper(), COLOR_CYAN, Vector2(0, 50))
		_compact_menu_button(replay, 50.0)
		_content.add_child(replay)
	var world_button := _make_action_button(&"results_world", "◎  WORLD", COLOR_MAGENTA, Vector2(0, 50))
	var settings := _make_action_button(&"settings", "⌁  SETTINGS", COLOR_BLUE, Vector2(0, 50))
	for button in [world_button, settings]:
		_compact_menu_button(button, 50.0)
		_tight_sides(button, 8)
	_content.add_child(_button_pair(world_button, settings))
	_content.add_child(_hint())

## Center: the outcome, time and score over the city's section as it stands now. Its open
## districts are pressable; after a seal the line shows where it moved from.
func show_world_results_map(report: Dictionary) -> void:
	var victory: bool = report.get("outcome", &"") == &"victory"
	var world: Dictionary = report.get("world", {})
	var city: Dictionary = report.get("city", {})
	var accent := COLOR_GREEN if victory else COLOR_RED
	_begin_wrap(accent, 0)
	var header := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		header.add_theme_constant_override(side, 20)
	header.add_theme_constant_override("margin_top", 12)
	header.add_theme_constant_override("margin_bottom", 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	header.add_child(row)
	var outcome := VBoxContainer.new()
	outcome.add_theme_constant_override("separation", 2)
	outcome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var complete: bool = world.get("operation_complete", false)
	var moved: bool = world.get("moved", victory)
	var subtitle := "LIFE FORCE DEPLETED"
	if complete:
		subtitle = "OPERATION COMPLETE"
	elif moved:
		subtitle = "DISTRICT SEALED"
	elif victory:
		subtitle = "ALL RIFTS SEALED"
	if report.has("tier"):
		subtitle += "  •  %s" % DifficultyTier.label(String(report.get("tier", "")))
	outcome.add_child(_label(subtitle, 16, accent, true))
	outcome.add_child(_label("MISSION COMPLETE" if victory else "OPERATION ENDED", 30, COLOR_TEXT, true))
	row.add_child(outcome)
	var seconds := float(report.get("seconds", 0.0))
	if victory and seconds > 0.0:
		var time_stack := VBoxContainer.new()
		time_stack.add_theme_constant_override("separation", 0)
		var time_label := _label(_clock(seconds), 40, COLOR_TEXT, true)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		time_stack.add_child(time_label)
		var previous := float(report.get("previous_best", 0.0))
		var new_best := previous > 0.0 and seconds < previous
		var note := _label("NEW BEST TIME" if new_best else "SEALED IN", 16, COLOR_GREEN if new_best else COLOR_MUTED, true)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		time_stack.add_child(note)
		row.add_child(time_stack)
	var score_stack := VBoxContainer.new()
	score_stack.add_theme_constant_override("separation", 0)
	var score_label := _label(_grouped(int(report.get("score", 0))), 28, accent, true)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_stack.add_child(score_label)
	var score_note := _label("SCORE", 16, COLOR_MUTED, true)
	score_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_stack.add_child(score_note)
	row.add_child(score_stack)
	_content.add_child(header)
	if city.is_empty():
		_content.add_child(_operations_map(world.get("section", {}), world.get("sealed_after", []), "", false))
	else:
		# A completed operation has already opened the next section, which shows fresh. Otherwise
		# the district just sealed is ringed and the old line drawn faint behind the new one.
		var traced := moved and not complete
		var sealed_before: Array = world.get("sealed_before", [])
		_content.add_child(_operations_map(
			city.get("section", {}),
			city.get("sealed", []),
			String(city.get("selected_id", "")),
			true,
			String((world.get("node", {}) as Dictionary).get("id", "")) if traced else "",
			sealed_before.size() if traced else -1
		))
	var debrief := String(report.get("debrief", ""))
	if debrief != "":
		var strip := MarginContainer.new()
		for side in ["margin_left", "margin_right"]:
			strip.add_theme_constant_override(side, 20)
		strip.add_theme_constant_override("margin_top", 10)
		strip.add_theme_constant_override("margin_bottom", 12)
		var line := _wrapped(debrief, 17, COLOR_TEXT)
		line.max_lines_visible = 2
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		strip.add_child(line)
		_content.add_child(strip)

## Right: the picked district and Deploy, as on the city map. After a defeat, until a district
## is picked, Retry leads instead, at the tier the round was played at.
func show_world_results_actions(report: Dictionary) -> void:
	var victory: bool = report.get("outcome", &"") == &"victory"
	var city: Dictionary = report.get("city", {})
	if not city.is_empty() and (victory or report.get("picked", false)):
		show_district_detail(city)
		return
	var tier := String(report.get("tier", DifficultyTier.STANDARD))
	var world: Dictionary = report.get("world", {})
	var entry: Dictionary = world.get("entry", {})
	var node: Dictionary = world.get("node", {})
	var tier_color := _tier_color(tier)
	_begin_wrap(tier_color)
	if victory:
		# A city with nothing left to deploy to.
		_content.add_child(_label("NEXT", 16, COLOR_MUTED, true))
		_content.add_child(_wrapped(String(entry.get("name", "")), 30, COLOR_TEXT, true))
		_content.add_child(_wrapped("Nothing is open here now. Pick another city on the world map.", 16, Color("c4d3e4")))
		_content.add_child(_spacer())
		_content.add_child(_make_solid_button(&"results_world", "WORLD MAP", COLOR_MAGENTA, 92.0))
		return
	_content.add_child(_wrapped("TRY AGAIN  •  %s" % String(entry.get("name", "")).to_upper(), 16, COLOR_MUTED, true))
	_content.add_child(_wrapped(String(node.get("name", "")), 30, COLOR_TEXT, true))
	_content.add_child(_wrapped("%s held. Go again, or pick another open district on the map." % node.get("name", "The district"), 16, Color("c4d3e4")))
	_content.add_child(_wrapped("%s  •  %s" % [String(world.get("kind_label", "")), DifficultyTier.label(tier)], 16, COLOR_TEXT, true))
	_content.add_child(_spacer())
	_content.add_child(_make_solid_button(&"retry", "RETRY\n%s" % DifficultyTier.label(tier), tier_color, 92.0))
	if report.get("offer_training", false):
		_content.add_child(_make_action_button(&"results_training", "◈  REVIEW TRAINING", COLOR_VIOLET, Vector2(0, 60)))
