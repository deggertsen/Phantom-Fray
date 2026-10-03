extends Control
class_name VRMenuPanel

signal action_requested(action: StringName)

const COLOR_CYAN := Color("56dff5")
const COLOR_BLUE := Color("408cff")
const COLOR_VIOLET := Color("a26cff")
const COLOR_GREEN := Color("5cf2ae")
const COLOR_AMBER := Color("ffc85a")
const COLOR_RED := Color("ff5d78")
const COLOR_TEXT := Color("edf7ff")
const COLOR_MUTED := Color("8da4bd")
const COLOR_PANEL := Color(0.006, 0.012, 0.034, 0.99)
const COLOR_PANEL_SOFT := Color(0.018, 0.03, 0.075, 0.97)
const COLOR_MAGENTA := Color("ff3dc8")

var _content: VBoxContainer
var _footer_hint: Label
var _audio_player: AudioStreamPlayer
var _hover_stream: AudioStreamWAV
var _confirm_stream: AudioStreamWAV
var _scanline: ColorRect
var _status_light: ColorRect
var _settings_scroll: ScrollContainer
var _animation_time: float = 0.0

func _ready() -> void:
	set_process(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_shell()
	_build_audio()

func _process(delta: float) -> void:
	_animation_time += delta
	_update_thumbstick_scroll(delta)
	if _scanline:
		_scanline.position.y = fmod(_animation_time * 55.0, 780.0)
		_scanline.color.a = 0.04 + sin(_animation_time * 2.0) * 0.012
	if _status_light:
		_status_light.modulate.a = 0.55 + sin(_animation_time * 3.2) * 0.35

func _update_thumbstick_scroll(delta: float) -> void:
	if _settings_scroll == null or not is_instance_valid(_settings_scroll) or not _settings_scroll.is_visible_in_tree():
		return
	var scroll_input := 0.0
	for group_name in ["left_hand", "right_hand"]:
		var controller := get_tree().get_first_node_in_group(group_name) as XRController3D
		if controller:
			var value := controller.get_vector2("primary").y
			if absf(value) > absf(scroll_input):
				scroll_input = value
	if absf(scroll_input) < 0.22:
		return
	_settings_scroll.scroll_vertical += int(-scroll_input * 620.0 * delta)

func show_main_menu(deploy_detail: String = "Seal the next live rift before the window collapses") -> void:
	_begin_view(&"DEPLOYMENT", "RSF // OPERATOR INTERFACE", "PHANTOM FRAY", "RESONANCE RISING", COLOR_CYAN)
	_add_copy("THE BREACH IS ACTIVE", "Deploy the next contract, or open Operations and choose.", COLOR_MUTED)
	_content.add_child(_make_action_button(
		&"deploy",
		"⚡  DEPLOY MISSION\nLIVE COMBAT OPERATION\n%s" % deploy_detail,
		COLOR_MAGENTA,
		Vector2(0, 150),
		true
	))
	_content.add_child(_make_action_button(
		&"operations",
		"◉  OPERATIONS\nCHOOSE A CONTRACT\nThree live operations from Dr. Chen",
		COLOR_AMBER,
		Vector2(0, 96)
	))
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 22)
	secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(secondary)
	secondary.add_child(_make_action_button(
		&"training",
		"◈  START TRAINING\nLEARN THE COMBAT SYSTEM\nRecommended before first deployment",
		COLOR_VIOLET,
		Vector2(0, 118)
	))
	secondary.add_child(_make_action_button(
		&"settings",
		"⌁  OPEN SETTINGS\nAUDIO • HAPTICS • COMFORT\nCustomize your operator profile",
		COLOR_BLUE,
		Vector2(0, 118)
	))
	_set_footer("POINT AT A BUTTON  •  PULL TRIGGER TO SELECT  •  HOLD META BUTTON TO RECENTER")

func show_operations(entries: Array[Dictionary]) -> void:
	_begin_view(&"OPERATIONS", "RSF // MISSION SELECT", "CHOOSE AN OPERATION", "EACH SEAL TEACHES THE NEXT", COLOR_AMBER)
	for entry in entries:
		var unlocked: bool = entry.get("unlocked", false)
		var cleared: bool = entry.get("cleared", false)
		var accent := COLOR_GREEN if cleared else COLOR_MAGENTA if unlocked else COLOR_MUTED
		var detail := String(entry.get("summary", "")) if unlocked else String(entry.get("lock_reason", "Locked"))
		var state := "SEALED" if cleared else "OPEN" if unlocked else "LOCKED"
		var button := _make_action_button(
			StringName("mission_%s" % entry.get("id", "")),
			"%s  %s\n%s\n%s" % [entry.get("codename", ""), entry.get("title", ""), state, detail],
			accent,
			Vector2(0, 108),
			unlocked and not cleared
		)
		button.disabled = not unlocked
		_content.add_child(button)
	_content.add_child(_make_action_button(&"operations_back", "BACK TO MAIN MENU", COLOR_BLUE, Vector2(0, 68)))
	_set_footer("LOCKED CONTRACTS OPEN WHEN YOU SEAL THE ONE BEFORE THEM")

func show_tutorial(page_index: int, pages: Array[Dictionary]) -> void:
	var page: Dictionary = pages[page_index]
	_begin_view(&"TRAINING", "RSF // GUIDED ORIENTATION", "TRAINING", "MODULE %02d / %02d" % [page_index + 1, pages.size()], COLOR_VIOLET)
	var lesson := PanelContainer.new()
	lesson.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lesson.add_theme_stylebox_override("panel", _style_box(COLOR_PANEL_SOFT, page.get("color", COLOR_VIOLET), 2, 20))
	_content.add_child(lesson)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	lesson.add_child(margin)
	var lesson_stack := VBoxContainer.new()
	lesson_stack.add_theme_constant_override("separation", 14)
	margin.add_child(lesson_stack)
	lesson_stack.add_child(_label(page.get("eyebrow", "TRAINING OBJECTIVE"), 20, page.get("color", COLOR_VIOLET), true))
	lesson_stack.add_child(_label(page.get("title", ""), 42, COLOR_TEXT, true))
	var body := _label(page.get("body", ""), 26, COLOR_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lesson_stack.add_child(body)
	var callout := _label(page.get("callout", ""), 22, COLOR_AMBER, true)
	callout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lesson_stack.add_child(callout)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 18)
	_content.add_child(actions)
	if page_index > 0:
		actions.add_child(_make_action_button(&"tutorial_back", "BACK", COLOR_MUTED, Vector2(175, 72)))
	else:
		actions.add_child(_make_action_button(&"tutorial_exit", "EXIT TRAINING", COLOR_MUTED, Vector2(220, 72)))
	var continue_text := "COMPLETE TRAINING" if page_index == pages.size() - 1 else "CONTINUE"
	actions.add_child(_make_action_button(&"tutorial_continue", continue_text, COLOR_VIOLET, Vector2(270, 72), true))
	_set_footer("THIS LESSON WILL WAIT  •  SELECT CONTINUE WHEN YOU ARE READY  •  HOLD META TO RECENTER")

func show_settings(music_text: String, haptics_text: String, reduced_flashes: bool, from_pause: bool) -> void:
	_begin_view(&"SETTINGS", "RSF // OPERATOR PROFILE", "SETTINGS", "", COLOR_BLUE)
	var scroll_hint := _label("AIM AT PANEL • USE EITHER THUMBSTICK TO SCROLL", 16, COLOR_MUTED, true)
	scroll_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(scroll_hint)
	_settings_scroll = ScrollContainer.new()
	_settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_content.add_child(_settings_scroll)
	var settings_stack := VBoxContainer.new()
	settings_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_stack.add_theme_constant_override("separation", 14)
	_settings_scroll.add_child(settings_stack)
	settings_stack.add_child(_make_stepper("MUSIC VOLUME", music_text, "Soundtrack and mission music", &"music_down", &"music_up", COLOR_CYAN))
	settings_stack.add_child(_make_stepper("EFFECTS VOLUME", _effects_volume_text(), "Impacts, UI, heartbeat, and warnings", &"effects_down", &"effects_up", COLOR_MAGENTA))
	settings_stack.add_child(_make_stepper("HAPTIC STRENGTH", haptics_text, "Controller impact feedback", &"haptics_down", &"haptics_up", COLOR_VIOLET))
	settings_stack.add_child(_make_toggle(
		"REDUCED FLASHES",
		"ON" if reduced_flashes else "OFF",
		"Lower damage flashes, blur, and danger tint",
		&"settings_flashes",
		COLOR_GREEN if reduced_flashes else COLOR_AMBER
	))
	var back_text := "BACK TO PAUSE" if from_pause else "BACK TO MAIN MENU"
	_content.add_child(_make_action_button(&"settings_back", back_text, COLOR_BLUE, Vector2(0, 72), true))
	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size.y = 6
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(bottom_spacer)
	_set_footer("STATIONARY VR  •  NO ARTIFICIAL LOCOMOTION  •  HOLD META BUTTON TO RECENTER")

func show_pause() -> void:
	_begin_view(&"PAUSED", "RSF // MISSION CONTROL", "MISSION PAUSED", "COMBAT SYSTEMS SUSPENDED", COLOR_AMBER)
	_add_copy("YOUR MISSION IS SAFE", "Time, damage, spawning, and recovery remain frozen until you resume.", COLOR_MUTED)
	_content.add_child(_make_action_button(&"resume", "RESUME MISSION", COLOR_GREEN, Vector2(0, 92), true))
	_content.add_child(_make_action_button(&"pause_settings", "SETTINGS", COLOR_BLUE, Vector2(0, 82)))
	_content.add_child(_make_action_button(&"abort", "END MISSION", COLOR_RED, Vector2(0, 82)))
	_set_footer("POINT + TRIGGER TO SELECT  •  HOLD META BUTTON TO RECENTER")

func show_abort_confirmation() -> void:
	_begin_view(&"CONFIRM", "RSF // MISSION CONTROL", "END CURRENT MISSION?", "UNSAVED MISSION PROGRESS WILL BE LOST", COLOR_RED)
	_add_copy("RETURN TO OPERATIONS", "Your settings and completed training record will be preserved.", COLOR_MUTED)
	_content.add_child(_make_action_button(&"abort_cancel", "KEEP FIGHTING", COLOR_GREEN, Vector2(0, 92), true))
	_content.add_child(_make_action_button(&"abort_confirm", "END MISSION & RETURN", COLOR_RED, Vector2(0, 92)))
	_set_footer("SELECT KEEP FIGHTING TO RESUME WITHOUT LOSING PROGRESS")

func show_suspended() -> void:
	_begin_view(&"XR PAUSED", "RSF // TRACKING SAFETY", "HEADSET SESSION PAUSED", "COMBAT REMAINS FROZEN", COLOR_AMBER)
	_add_copy("RETURN TO YOUR PLAY SPACE", "Confirm your boundary and controller tracking before continuing.", COLOR_TEXT)
	_content.add_child(_make_action_button(&"resume", "RESUME WHEN READY", COLOR_GREEN, Vector2(0, 96), true))
	_set_footer("FACE FORWARD AND HOLD META BUTTON TO RECENTER BEFORE RESUMING")

func activate_at_viewport_point(point: Vector2) -> bool:
	var best: Array = [null, 1.0e9]
	_closest_button(self, point, best)
	var button := best[0] as Button
	if button == null:
		return false
	button.pressed.emit()
	return true

func _closest_button(node: Node, point: Vector2, best: Array) -> void:
	if node is Button:
		var button := node as Button
		var rect := button.get_global_rect().grow(42.0)
		if button.visible and not button.disabled and rect.has_point(point):
			var distance := rect.get_center().distance_to(point)
			if distance < float(best[1]):
				best[0] = button
				best[1] = distance
	for child in node.get_children():
		_closest_button(child, point, best)

func show_results(outcome: StringName, score: int, debrief: String = "", next_title: String = "") -> void:
	var victory := outcome == &"victory"
	var title := "MISSION COMPLETE" if victory else "OPERATION ENDED"
	var subtitle := "ALL RIFTS SEALED" if victory else "LIFE FORCE DEPLETED" if outcome == &"defeat" else "RIFT WINDOW LOST"
	var accent := COLOR_GREEN if victory else COLOR_RED
	_begin_view(&"RESULTS", "RSF // AFTER-ACTION REPORT", title, subtitle, accent, 34)
	var outcome_banner := ColorRect.new()
	outcome_banner.custom_minimum_size.y = 6
	outcome_banner.color = accent
	outcome_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(outcome_banner)
	var score_panel := PanelContainer.new()
	score_panel.add_theme_stylebox_override("panel", _style_box(COLOR_PANEL_SOFT, accent, 2, 18))
	_content.add_child(score_panel)
	var score_label := _label("FINAL SCORE  %06d" % score, 28, accent, true)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_panel.add_child(score_label)
	if debrief != "":
		var debrief_label := _label(debrief, 18, COLOR_TEXT)
		debrief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(debrief_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size.y = 8
	_content.add_child(spacer)
	if next_title != "":
		_content.add_child(_make_action_button(&"next_mission", "NEXT OPERATION\n%s" % next_title, COLOR_GREEN, Vector2(0, 64), true))
	_content.add_child(_make_action_button(&"retry", "RETRY MISSION", COLOR_CYAN, Vector2(0, 58), next_title == ""))
	_content.add_child(_make_action_button(&"results_menu", "MAIN MENU", COLOR_BLUE, Vector2(0, 58)))
	_set_footer("POINT + TRIGGER TO SELECT YOUR NEXT OPERATION")

func _build_shell() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.002, 0.006, 0.018, 1.0)
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.0, 0.0, 0.0, 0.18)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var glow := Panel.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.add_theme_stylebox_override("panel", _style_box(Color(0.004, 0.01, 0.028, 0.97), Color(COLOR_CYAN, 0.62), 3, 28, 16))
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	var top_rail := ColorRect.new()
	top_rail.position = Vector2(0, 0)
	top_rail.size = Vector2(1280, 7)
	top_rail.color = COLOR_MAGENTA
	top_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_rail)
	var side_rail := ColorRect.new()
	side_rail.position = Vector2(0, 0)
	side_rail.size = Vector2(7, 780)
	side_rail.color = COLOR_CYAN
	side_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(side_rail)
	_build_cyber_grid()
	_scanline = ColorRect.new()
	_scanline.position = Vector2(7, 0)
	_scanline.size = Vector2(1273, 3)
	_scanline.color = Color(COLOR_CYAN, 0.05)
	_scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scanline)
	_build_corner_brackets()
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 64)
	outer.add_theme_constant_override("margin_right", 64)
	outer.add_theme_constant_override("margin_top", 50)
	outer.add_theme_constant_override("margin_bottom", 44)
	add_child(outer)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	outer.add_child(_content)

func _build_corner_brackets() -> void:
	var corners := [
		[Vector2(22, 22), Vector2(62, 4), Vector2(4, 62)],
		[Vector2(1196, 22), Vector2(62, 4), Vector2(4, 62)],
		[Vector2(22, 754), Vector2(62, 4), Vector2(4, 62)],
		[Vector2(1196, 754), Vector2(62, 4), Vector2(4, 62)],
	]
	for index in range(corners.size()):
		var horizontal := ColorRect.new()
		horizontal.position = corners[index][0]
		horizontal.size = corners[index][1]
		horizontal.color = COLOR_MAGENTA if index in [1, 2] else COLOR_CYAN
		horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(horizontal)
		var vertical := ColorRect.new()
		vertical.position = corners[index][0]
		vertical.size = corners[index][2]
		vertical.color = horizontal.color
		vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(vertical)

func _build_cyber_grid() -> void:
	for x in range(80, 1280, 160):
		var line := ColorRect.new()
		line.position = Vector2(x, 0)
		line.size = Vector2(1, 780)
		line.color = Color(COLOR_CYAN, 0.035)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
	for y in range(70, 780, 90):
		var line := ColorRect.new()
		line.position = Vector2(0, y)
		line.size = Vector2(1280, 1)
		line.color = Color(COLOR_MAGENTA, 0.025)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)

func _begin_view(section: StringName, system_title: String, title: String, subtitle: String, accent: Color, title_size: int = 54) -> void:
	_clear_content()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_content.add_child(top)
	_status_light = ColorRect.new()
	_status_light.custom_minimum_size = Vector2(12, 12)
	_status_light.color = accent
	_status_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_status_light)
	var system := _label("ONLINE  //  %s" % system_title, 18, COLOR_MUTED, true)
	system.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(system)
	var badge := Label.new()
	badge.text = "  %s  " % section
	badge.add_theme_font_size_override("font_size", 17)
	badge.add_theme_color_override("font_color", accent)
	badge.add_theme_stylebox_override("normal", _style_box(Color(0.02, 0.05, 0.1, 0.92), accent, 1, 10))
	top.add_child(badge)
	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 4
	divider.color = accent
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(divider)
	var heading := _label(title, title_size, COLOR_TEXT, true)
	heading.add_theme_color_override("font_shadow_color", Color(accent, 0.4))
	heading.add_theme_constant_override("shadow_offset_x", 3)
	heading.add_theme_constant_override("shadow_offset_y", 3)
	_content.add_child(heading)
	_content.add_child(_label(subtitle, 22, accent, true))

func _add_copy(title: String, body: String, color: Color) -> void:
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 6)
	copy.add_child(_label(title, 25, COLOR_TEXT, true))
	var body_label := _label(body, 20, color)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(body_label)
	_content.add_child(copy)

func _make_action_button(action: StringName, text: String, accent: Color, minimum_size: Vector2, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 22 if primary else 20)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal_fill := Color(accent, 0.11) if primary else Color(0.025, 0.055, 0.11, 0.96)
	var normal_border := accent if primary else Color(accent, 0.42)
	button.add_theme_stylebox_override("normal", _style_box(normal_fill, normal_border, 3 if primary else 2, 18, 7 if primary else 0))
	button.add_theme_stylebox_override("hover", _style_box(Color(accent, 0.19), accent, 4, 18, 12))
	button.add_theme_stylebox_override("pressed", _style_box(Color(accent, 0.34), Color.WHITE, 4, 18, 6))
	button.add_theme_stylebox_override("disabled", _style_box(Color(0.02, 0.025, 0.04, 0.8), Color(0.2, 0.25, 0.32, 0.4), 1, 18))
	button.set_meta(&"menu_action", action)
	button.pressed.connect(_on_action_pressed.bind(action))
	button.mouse_entered.connect(_on_button_hovered.bind(button))
	return button

func _effects_volume_text() -> String:
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null:
		return "--"
	return "MUTED" if settings.sfx_db <= -79.0 else "%d dB" % int(settings.sfx_db)

func _make_stepper(label_text: String, value_text: String, description: String, down_action: StringName, up_action: StringName, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_box(COLOR_PANEL_SOFT, Color(accent, 0.55), 2, 16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(_label(label_text, 22, COLOR_TEXT, true))
	copy.add_child(_label(description, 17, COLOR_MUTED))
	row.add_child(copy)
	row.add_child(_make_action_button(down_action, "−", accent, Vector2(74, 68)))
	var value := _label(value_text, 25, accent, true)
	value.custom_minimum_size = Vector2(130, 68)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	row.add_child(_make_action_button(up_action, "+", accent, Vector2(74, 68)))
	return panel

func _make_toggle(label_text: String, value_text: String, description: String, action: StringName, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_box(COLOR_PANEL_SOFT, Color(accent, 0.55), 2, 16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(_label(label_text, 22, COLOR_TEXT, true))
	copy.add_child(_label(description, 17, COLOR_MUTED))
	row.add_child(copy)
	row.add_child(_make_action_button(action, value_text, accent, Vector2(210, 68), true))
	return panel

func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_color_override("font_outline_color", Color(color, 0.35))
	return label

func _set_footer(text: String) -> void:
	_footer_hint = _label(text, 16, COLOR_MUTED, true)
	_footer_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer_hint.size_flags_vertical = Control.SIZE_SHRINK_END
	_content.add_child(_footer_hint)

func _style_box(background: Color, border_color: Color, border_width: int, radius: int, shadow_size: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	if shadow_size > 0:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
		style.shadow_size = shadow_size
	return style

func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()

func _on_action_pressed(action: StringName) -> void:
	_play_ui_sound(_confirm_stream)
	action_requested.emit(action)

func _on_button_hovered(_button: Button) -> void:
	_play_ui_sound(_hover_stream)

func _build_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = &"UI"
	_audio_player.volume_db = -8.0
	add_child(_audio_player)
	_hover_stream = _create_tone(660.0, 0.035, 0.14)
	_confirm_stream = _create_tone(880.0, 0.07, 0.22)

func _play_ui_sound(stream: AudioStreamWAV) -> void:
	if _audio_player == null or stream == null:
		return
	_audio_player.stream = stream
	_audio_player.play()

func _create_tone(frequency: float, duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in range(sample_count):
		var envelope := 1.0 - float(index) / maxf(sample_count - 1, 1)
		var value := sin(TAU * frequency * float(index) / sample_rate) * envelope * amplitude
		var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
		data[index * 2] = sample & 0xff
		data[index * 2 + 1] = (sample >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
