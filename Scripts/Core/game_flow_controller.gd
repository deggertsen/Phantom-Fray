extends Node

const STATE_MENU := &"menu"
const STATE_TUTORIAL := &"tutorial"
const STATE_PLAYING := &"playing"
const STATE_PAUSED := &"paused"
const STATE_SETTINGS := &"settings"
const STATE_RESULTS := &"results"
const STATE_ABORT_CONFIRM := &"abort_confirm"

var _state: StringName = STATE_MENU
var _previous_state: StringName = STATE_MENU
var _round: RoundController
var _player: Node3D
var _presenter: VRMenuPresenter
var _tutorial_step: int = 0
var _settings: Node
var _last_outcome: StringName = &""
var _last_score: int = 0
var _menu_input_armed: bool = false
var _results_pointer_warmup: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_round = get_tree().get_first_node_in_group("RoundController") as RoundController
	_player = get_tree().get_first_node_in_group("Player") as Node3D
	_presenter = get_tree().get_first_node_in_group("VRMenuPresenter") as VRMenuPresenter
	_settings = get_node_or_null("/root/GameSettings")
	if _round:
		_round.round_finished.connect(_on_round_finished)
	if _presenter:
		_presenter.action_requested.connect(_on_menu_action)
	_connect_controller_buttons()
	_show_main_menu()
	_arm_menu_input_after_release()

func _process(delta: float) -> void:
	if _state != STATE_RESULTS or _results_pointer_warmup <= 0.0:
		return
	_results_pointer_warmup -= delta
	_set_menu_pointers_enabled(true)
	if _results_pointer_warmup <= 0.0:
		_arm_menu_input_after_release()

func _connect_controller_buttons() -> void:
	if _player == null:
		return
	for path in [NodePath("LeftHandController"), NodePath("RightHandController")]:
		var controller := _player.get_node_or_null(path) as XRController3D
		if controller:
			controller.button_pressed.connect(_on_controller_button_pressed)

func _on_controller_button_pressed(button: String) -> void:
	if button == "trigger_click" and _state == STATE_RESULTS:
		for controller_name in ["LeftHandController", "RightHandController"]:
			var pointer := _player.get_node_or_null(NodePath("%s/MenuPointer" % controller_name)) as XRToolsFunctionPointer
			if pointer and pointer.click_current_target():
				return
	# The Meta system button owns recentering. We only consume the app-menu action for pause.
	if button == "menu_button" and _state == STATE_PLAYING and _round and _round.is_round_in_progress():
		_pause_game()

func _on_menu_action(action: StringName) -> void:
	if _state != STATE_RESULTS:
		if not _menu_input_armed:
			return
		_menu_input_armed = false
		get_tree().create_timer(0.25).timeout.connect(_arm_menu_input_after_release)
	match action:
		&"deploy":
			_start_mission()
		&"training", &"results_training":
			_start_tutorial()
		&"settings":
			_show_settings(STATE_MENU)
		&"music_down":
			if _settings:
				_settings.adjust_music(-1)
			_render_settings()
		&"music_up":
			if _settings:
				_settings.adjust_music(1)
			_render_settings()
		&"effects_down":
			if _settings:
				_settings.adjust_effects(-1)
			_render_settings()
		&"effects_up":
			if _settings:
				_settings.adjust_effects(1)
			_render_settings()
		&"haptics_down":
			if _settings:
				_settings.adjust_haptics(-1)
			_render_settings()
		&"haptics_up":
			if _settings:
				_settings.adjust_haptics(1)
			_render_settings()
		&"settings_flashes":
			if _settings:
				_settings.reduced_flashes = not _settings.reduced_flashes
				_settings.save_settings()
			_render_settings()
		&"settings_back":
			if _previous_state == STATE_PAUSED:
				_show_pause_menu()
			elif _previous_state == STATE_RESULTS:
				_show_results()
			else:
				_show_main_menu()
		&"tutorial_continue":
			_advance_tutorial()
		&"tutorial_back":
			_tutorial_step = maxi(_tutorial_step - 1, 0)
			_render_tutorial()
		&"tutorial_exit":
			_show_main_menu()
		&"resume":
			_resume_game()
		&"pause_settings":
			_show_settings(STATE_PAUSED)
		&"abort":
			_state = STATE_ABORT_CONFIRM
			_set_menu_visible(true)
			if _presenter:
				_presenter.show_abort_confirmation()
		&"abort_cancel":
			_show_pause_menu()
		&"abort_confirm":
			get_tree().reload_current_scene()
		&"retry":
			get_tree().reload_current_scene()
		&"results_menu":
			get_tree().reload_current_scene()

func _arm_menu_input_after_release() -> void:
	if _player == null:
		_menu_input_armed = true
		return
	for path in [NodePath("LeftHandController"), NodePath("RightHandController")]:
		var controller := _player.get_node_or_null(path) as XRController3D
		if controller and controller.is_button_pressed("trigger_click"):
			get_tree().create_timer(0.1).timeout.connect(_arm_menu_input_after_release)
			return
	_menu_input_armed = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_SPACE:
				if _state == STATE_MENU:
					_on_menu_action(&"deploy")
				elif _state == STATE_TUTORIAL:
					_on_menu_action(&"tutorial_continue")
				elif _state == STATE_PAUSED:
					_on_menu_action(&"resume")
			KEY_T:
				_on_menu_action(&"training")
			KEY_S:
				_show_settings(_state)
			KEY_ESCAPE:
				if _state == STATE_PLAYING:
					_pause_game()
				elif _state in [STATE_TUTORIAL, STATE_SETTINGS, STATE_RESULTS]:
					_show_main_menu()

func _show_main_menu() -> void:
	_state = STATE_MENU
	_set_menu_visible(true)
	if _presenter:
		_presenter.show_main_menu()

func _start_mission() -> void:
	_state = STATE_PLAYING
	_set_menu_visible(false)
	if _round:
		_round.begin_round()

func _start_tutorial() -> void:
	_state = STATE_TUTORIAL
	_tutorial_step = 0
	_set_menu_visible(true)
	_render_tutorial()

func _advance_tutorial() -> void:
	_tutorial_step += 1
	if _tutorial_step >= _tutorial_pages().size():
		if _settings:
			_settings.tutorial_completed = true
			_settings.save_settings()
		_show_main_menu()
		return
	_render_tutorial()

func _render_tutorial() -> void:
	_state = STATE_TUTORIAL
	_set_menu_visible(true)
	if _presenter:
		_presenter.show_tutorial(_tutorial_step, _tutorial_pages())

func _tutorial_pages() -> Array[Dictionary]:
	return [
		{
			"eyebrow": "MODULE 01 // SAFE PLAY SPACE",
			"title": "CENTER YOUR OPERATING AREA",
			"body": "Stay inside the cyan floor ring. Clear room to punch, duck, and take one small step left or right.",
			"callout": "Hold Meta to recenter. This page waits until you select Continue.",
			"color": Color("56dff5"),
		},
		{
			"eyebrow": "MODULE 02 // ERM GAUNTLETS",
			"title": "GRIP, THEN STRIKE",
			"body": "Hold Grip, then punch. Release Grip when you are not striking.",
			"callout": "Jabs, hooks, and uppercuts work. Never punch outside your boundary.",
			"color": Color("5cf2ae"),
		},
		{
			"eyebrow": "MODULE 03 // RESONANCE PHANTOMS",
			"title": "MATCH THE GAUNTLET",
			"body": "YELLOW = LEFT hand. BLUE = RIGHT hand. Hit the glowing point for bonus score and rift damage.",
			"callout": "Wrong-hand strikes are rejected. Aim—do not swing wildly.",
			"color": Color("a26cff"),
		},
		{
			"eyebrow": "MODULE 04 // DEFENSIVE RESPONSES",
			"title": "BLOCK GREEN • DODGE PINK",
			"body": "GREEN = strike with both hands quickly. PINK = move out of its locked attack lane.",
			"callout": "Pink cannot be punched. Side-step or duck with controlled movement.",
			"color": Color("ffc85a"),
		},
		{
			"eyebrow": "MODULE 05 // LIFE FORCE",
			"title": "DO NOT LET THEM INSIDE",
			"body": "Phantom contact drains life force. Your wrist shows life, score, multiplier, rifts, and time.",
			"callout": "Life recovers when clear. Low life increases heartbeat and danger tint.",
			"color": Color("ff5d78"),
		},
		{
			"eyebrow": "MODULE 06 // MISSION OBJECTIVE",
			"title": "SEAL THREE RIFTS",
			"body": "Defeat Phantoms to weaken their rift. Seal three rifts before the four-minute window closes.",
			"callout": "Training complete. Return to Main Menu, then select Deploy Mission for live combat.",
			"color": Color("56dff5"),
		},
	]

func _pause_game() -> void:
	_state = STATE_PAUSED
	if _round:
		_round.pause_round()
	_show_pause_menu()

func show_suspended_pause() -> void:
	_state = STATE_PAUSED
	_set_menu_visible(true)
	if _presenter:
		_presenter.show_suspended()

func _show_pause_menu() -> void:
	_state = STATE_PAUSED
	_set_menu_visible(true)
	if _presenter:
		_presenter.show_pause()

func _resume_game() -> void:
	if _round == null or not _round.can_resume_round():
		return
	_state = STATE_PLAYING
	_set_menu_visible(false)
	_round.resume_round()

func _show_settings(return_state: StringName) -> void:
	_previous_state = return_state
	_state = STATE_SETTINGS
	_set_menu_visible(true)
	_render_settings()

func _render_settings() -> void:
	var music := "--"
	var haptics := "--"
	var reduced_flashes := false
	if _settings:
		music = "MUTED" if _settings.music_db <= -79.0 else "%d dB" % int(_settings.music_db)
		haptics = "%d%%" % int(_settings.haptic_scale * 100.0)
		reduced_flashes = _settings.reduced_flashes
	if _presenter:
		_presenter.show_settings(music, haptics, reduced_flashes, _previous_state == STATE_PAUSED)

func restore_current_menu() -> void:
	match _state:
		STATE_MENU:
			_show_main_menu()
		STATE_TUTORIAL:
			_render_tutorial()
		STATE_SETTINGS:
			_render_settings()
		STATE_PAUSED:
			_show_pause_menu()
		STATE_RESULTS:
			_show_results()
		STATE_ABORT_CONFIRM:
			_set_menu_visible(true)
			if _presenter:
				_presenter.show_abort_confirmation()
		_:
			pass

func recenter_current_panel() -> void:
	if _presenter:
		_presenter.recenter()

func _on_round_finished(outcome: StringName, score: int) -> void:
	_last_outcome = outcome
	_last_score = score
	_state = STATE_RESULTS
	_menu_input_armed = false
	_show_results()
	_arm_menu_input_after_release()

func _show_results() -> void:
	_state = STATE_RESULTS
	_rebuild_menu_pointers()
	_set_menu_visible(true)
	_menu_input_armed = false
	_results_pointer_warmup = 1.0
	if _presenter:
		_presenter.show_results(_last_outcome, _last_score)
	_set_menu_pointers_enabled(true)
	call_deferred("_reset_results_pointers_after_render")

func _reset_results_pointers_after_render() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_set_menu_pointers_enabled(true)
	_menu_input_armed = true

func _set_menu_visible(is_visible: bool) -> void:
	_set_menu_pointers_enabled(is_visible)
	if _presenter == null:
		return
	if is_visible:
		_presenter.visible = true
	else:
		_presenter.hide_menu()

func _rebuild_menu_pointers() -> void:
	if _player == null:
		return
	for controller_name in ["LeftHandController", "RightHandController"]:
		var controller := _player.get_node_or_null(NodePath(controller_name)) as XRController3D
		if controller == null:
			continue
		var old_pointer := controller.get_node_or_null("MenuPointer")
		if old_pointer:
			controller.remove_child(old_pointer)
			old_pointer.queue_free()
		var pointer := preload("res://addons/godot-xr-tools/functions/function_pointer.tscn").instantiate() as XRToolsFunctionPointer
		pointer.name = "MenuPointer"
		pointer.enabled = true
		pointer.distance = 8.0
		pointer.show_laser = XRToolsFunctionPointer.LaserShow.SHOW
		pointer.laser_length = XRToolsFunctionPointer.LaserLength.COLLIDE
		pointer.show_target = true
		pointer.target_radius = 0.018
		pointer.process_mode = Node.PROCESS_MODE_ALWAYS
		controller.add_child(pointer)
		pointer.call_deferred("reset_pointer_state")

func _set_menu_pointers_enabled(enabled: bool) -> void:
	if _player == null:
		return
	for controller_name in ["LeftHandController", "RightHandController"]:
		var pointer := _player.get_node_or_null(NodePath("%s/MenuPointer" % controller_name)) as XRToolsFunctionPointer
		if pointer:
			pointer.process_mode = Node.PROCESS_MODE_ALWAYS if enabled else Node.PROCESS_MODE_INHERIT
			if enabled and pointer.has_method("reset_pointer_state"):
				pointer.reset_pointer_state()
			pointer.set_process(enabled)
			pointer.enabled = enabled
