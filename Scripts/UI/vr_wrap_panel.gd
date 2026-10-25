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
	var settings := _make_action_button(&"settings", "⌁  SETTINGS\nAudio • haptics • comfort", COLOR_BLUE, Vector2(0, 70))
	for button in [training, settings]:
		_compact_menu_button(button, 70.0)
		_content.add_child(button)
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
