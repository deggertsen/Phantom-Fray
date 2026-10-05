extends Node

const STATE_MENU := &"menu"
const STATE_TUTORIAL := &"tutorial"
const STATE_PLAYING := &"playing"
const STATE_PAUSED := &"paused"
const STATE_SETTINGS := &"settings"
const STATE_RESULTS := &"results"
const STATE_ABORT_CONFIRM := &"abort_confirm"
const STATE_RESET_CONFIRM := &"reset_confirm"

var _state: StringName = STATE_MENU
var _previous_state: StringName = STATE_MENU
var _round: RoundController
var _player: Node3D
var _presenter: VRMenuPresenter
var _tutorial_step: int = 0
var _settings: Node
var _last_outcome: StringName = &""
var _last_score: int = 0
var _active_mission_id: String = ""
var _last_debrief: String = ""
var _next_mission_title: String = ""
var _menu_input_armed: bool = false
var _results_pointer_warmup: float = 0.0
var _results_action_locked: bool = false
var _menu_trigger_down: bool = false
var _trigger_controller: XRController3D
var _menu_action_cooldown: float = 0.0

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
	var pending := ""
	if _settings:
		pending = String(_settings.pending_mission_id)
		_settings.pending_mission_id = ""
	if pending != "" and not MissionCatalog.get_mission(pending).is_empty():
		_start_mission(pending)
	else:
		_show_main_menu()
		_arm_menu_input_after_release()

func _process(delta: float) -> void:
	if _menu_action_cooldown > 0.0:
		_menu_action_cooldown = maxf(_menu_action_cooldown - delta, 0.0)
	if _state == STATE_RESULTS and _results_pointer_warmup > 0.0:
		_results_pointer_warmup -= delta
		if _results_pointer_warmup <= 0.0:
			_sync_menu_trigger_baseline()
			_menu_input_armed = true
	if _presenter != null and _presenter.is_menu_visible():
		_hold_menu_pointers()
	_poll_menu_trigger()

func _connect_controller_buttons() -> void:
	if _player == null:
		return
	for path in [NodePath("LeftHandController"), NodePath("RightHandController")]:
		var controller := _player.get_node_or_null(path) as XRController3D
		if controller:
			controller.button_pressed.connect(_on_controller_button_pressed.bind(controller))

func _on_controller_button_pressed(button: String, controller: XRController3D = null) -> void:
	if button == "trigger_click" and controller and _presenter and _presenter.is_menu_visible():
		_menu_trigger_down = true
		_trigger_controller = controller
		return
	# The Meta system button owns recentering. We only consume the app-menu action for pause.
	if button == "menu_button" and _state == STATE_PLAYING and _round and _round.is_round_in_progress():
		_pause_game()

func _on_menu_action(action: StringName) -> void:
	if _menu_action_cooldown > 0.0 or not _action_belongs_to_state(action):
		return
	_menu_action_cooldown = 0.45
	if _state != STATE_RESULTS:
		if not _menu_input_armed:
			return
		_menu_input_armed = false
		get_tree().create_timer(0.25).timeout.connect(_arm_menu_input_after_release)
	if String(action).begins_with("mission_"):
		_start_mission(String(action).trim_prefix("mission_"))
		return
	match action:
		&"deploy":
			_start_mission("")
		&"operations":
			_show_operations()
		&"operations_back":
			_show_main_menu()
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
		&"settings_flashes_off":
			if _settings:
				_settings.reduced_flashes = false
				_settings.save_settings()
			_render_settings()
		&"settings_flashes_on":
			if _settings:
				_settings.reduced_flashes = true
				_settings.save_settings()
			_render_settings()
		&"reset_progress":
			_state = STATE_RESET_CONFIRM
			_set_menu_visible(true)
			if _presenter:
				_presenter.show_reset_confirmation()
		&"reset_cancel":
			_state = STATE_SETTINGS
			_render_settings()
		&"reset_confirm":
			if _settings:
				_settings.reset_mission_progress()
			_state = STATE_SETTINGS
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
		&"retry", &"next_mission", &"results_menu":
			if _results_action_locked:
				return
			_results_action_locked = true
			_menu_input_armed = false
			if action == &"results_menu":
				_return_to_operations_menu()
			else:
				var mission_id := _active_mission_id
				if action == &"next_mission" and _settings:
					var follow := MissionCatalog.unlocked_followup(_active_mission_id, _settings)
					if follow != "":
						mission_id = follow
				_restart_mission(mission_id)

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
		_presenter.show_main_menu(MissionCatalog.deploy_detail(_settings))

func _show_operations() -> void:
	_state = STATE_MENU
	_set_menu_visible(true)
	if _presenter:
		_presenter.show_operations(MissionCatalog.operation_entries(_settings))

func _start_mission(mission_id: String = "") -> void:
	var resolved_id := mission_id if mission_id != "" else MissionCatalog.next_unlocked_id(_settings)
	var mission := MissionCatalog.get_mission(resolved_id)
	if mission.is_empty() or not MissionCatalog.is_unlocked(resolved_id, _settings):
		_show_main_menu()
		return
	_active_mission_id = resolved_id
	_state = STATE_PLAYING
	_set_menu_visible(false)
	if _round:
		_round.begin_round(mission)

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
			"body": "YELLOW arcs in from your LEFT. BLUE arcs from the RIGHT. They speed up as they arrive. Punch when they reach you. The bright point is a crit.",
			"callout": "An edge marker tells you where to turn. A clean hit keeps your chain. The wrong hand breaks it.",
			"color": Color("a26cff"),
		},
		{
			"eyebrow": "MODULE 04 // DEFENSIVE RESPONSES",
			"title": "BLOCK GREEN • DODGE PINK",
			"body": "GREEN widens, then crashes your chest. Catch it with both hands on that beat. PINK paints a lane, then charges it.",
			"callout": "The first hand on a Green is a catch, not a miss. Pink cannot be punched. Leave the lane.",
			"color": Color("ffc85a"),
		},
		{
			"eyebrow": "MODULE 05 // LIFE FORCE",
			"title": "DO NOT LET THEM INSIDE",
			"body": "If a phantom reaches your head, it possesses you: it vanishes and drains a chunk of life force. Your vision blurs for a moment and the wrist meter drops.",
			"callout": "Life recovers when the air is clear. Low life raises the heartbeat.",
			"color": Color("ff5d78"),
		},
		{
			"eyebrow": "MODULE 06 // MISSION OBJECTIVE",
			"title": "SEAL THE RIFT, THEN THE NEXT",
			"body": "A column of light marks each open rift. If it is outside your view, a RIFT chevron sits at the edge of your sight until you turn to face it.",
			"callout": "Each rift hits harder than the last. Deploy First Light when you are ready.",
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
	var effects := "--"
	var haptics := "--"
	var reduced_flashes := false
	if _settings:
		music = _settings.volume_label(_settings.music_db)
		effects = _settings.volume_label(_settings.sfx_db)
		haptics = "%d%%" % int(_settings.haptic_scale * 100.0)
		reduced_flashes = _settings.reduced_flashes
	if _presenter:
		_presenter.show_settings(music, effects, haptics, reduced_flashes, _previous_state == STATE_PAUSED)

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
		STATE_RESET_CONFIRM:
			_set_menu_visible(true)
			if _presenter:
				_presenter.show_reset_confirmation()
		_:
			pass

func recenter_current_panel() -> void:
	if _presenter:
		_presenter.recenter()

func _on_round_finished(outcome: StringName, score: int) -> void:
	_last_outcome = outcome
	_last_score = score
	_last_debrief = _round.get_debrief(outcome) if _round else ""
	_next_mission_title = ""
	if outcome == &"victory" and _settings:
		_settings.mark_mission_cleared(_active_mission_id)
		var follow_id := MissionCatalog.unlocked_followup(_active_mission_id, _settings)
		if follow_id != "":
			_next_mission_title = String(MissionCatalog.get_mission(follow_id).get("title", ""))
	_state = STATE_RESULTS
	_menu_input_armed = false
	_show_results()
	_arm_menu_input_after_release()

func _show_results() -> void:
	_state = STATE_RESULTS
	_results_action_locked = false
	_set_menu_visible(true)
	_menu_input_armed = false
	_results_pointer_warmup = 0.35
	if _presenter:
		_presenter.show_results(_last_outcome, _last_score, _last_debrief, _next_mission_title)
	_refresh_menu_pointers()
	call_deferred("_reset_results_pointers_after_render")

func _poll_menu_trigger() -> void:
	if _player == null or _presenter == null or not _presenter.is_menu_visible() or _state == STATE_PLAYING:
		_menu_trigger_down = false
		return
	var down := false
	var held: XRController3D = null
	for path in [NodePath("LeftHandController"), NodePath("RightHandController")]:
		var controller := _player.get_node_or_null(path) as XRController3D
		if controller and controller.is_button_pressed("trigger_click"):
			down = true
			held = controller
	var released := _menu_trigger_down and not down
	var who := _trigger_controller
	_menu_trigger_down = down
	if down:
		_trigger_controller = held
	if released and _menu_input_armed and who != null:
		_activate_menu_from_controller(who)

func _action_belongs_to_state(action: StringName) -> bool:
	match _state:
		STATE_RESULTS:
			return action in [&"retry", &"next_mission", &"results_menu"]
		STATE_SETTINGS:
			return action in [&"music_down", &"music_up", &"effects_down", &"effects_up", &"haptics_down", &"haptics_up", &"settings_flashes_off", &"settings_flashes_on", &"reset_progress", &"settings_back"]
		STATE_RESET_CONFIRM:
			return action in [&"reset_cancel", &"reset_confirm"]
		STATE_MENU:
			return String(action).begins_with("mission_") or action in [&"deploy", &"operations", &"operations_back", &"training", &"settings"]
		STATE_TUTORIAL:
			return action in [&"tutorial_continue", &"tutorial_back", &"tutorial_exit", &"results_training"]
		STATE_PAUSED:
			return action in [&"resume", &"pause_settings", &"abort"]
		STATE_ABORT_CONFIRM:
			return action in [&"abort_cancel", &"abort_confirm"]
		_:
			return false

func _sync_menu_trigger_baseline() -> void:
	_menu_trigger_down = false
	if _player == null:
		return
	for path in [NodePath("LeftHandController"), NodePath("RightHandController")]:
		var controller := _player.get_node_or_null(path) as XRController3D
		if controller and controller.is_button_pressed("trigger_click"):
			_menu_trigger_down = true

func _activate_menu_from_controller(controller: XRController3D) -> void:
	if _presenter == null:
		return
	var pointer := controller.get_node_or_null("MenuPointer") as Node3D
	var aim_from: Node3D = pointer if pointer != null else controller
	var direction := -aim_from.global_transform.basis.z
	if _presenter.activate_from_aim(aim_from.global_position, direction):
		return
	if pointer == null:
		return
	# https://docs.godotengine.org/en/stable/classes/class_raycast3d.html#class-raycast3d-method-force-raycast-update
	var ray := pointer.get_node_or_null("RayCast") as RayCast3D
	if ray == null:
		return
	ray.enabled = true
	ray.force_raycast_update()
	var body: Object = ray.get_collider() if ray.is_colliding() else null
	var hit: Vector3 = ray.get_collision_point() if ray.is_colliding() else Vector3.ZERO
	if body == null or not body.has_method("global_to_viewport"):
		return
	var point: Vector2 = body.global_to_viewport(hit)
	_presenter.activate_at_viewport_point(point)

func _restart_mission(mission_id: String) -> void:
	var mission := MissionCatalog.get_mission(mission_id)
	if mission.is_empty() or _round == null or not MissionCatalog.is_unlocked(mission_id, _settings):
		_results_action_locked = false
		_return_to_operations_menu()
		return
	_active_mission_id = mission_id
	_round.abandon_round()
	_state = STATE_PLAYING
	_set_menu_visible(false)
	_round.begin_round(mission)

func _return_to_operations_menu() -> void:
	if _round:
		_round.abandon_round()
	_results_action_locked = false
	_show_main_menu()
	_menu_input_armed = false
	_sync_menu_trigger_baseline()
	_arm_menu_input_after_release()

func _reset_results_pointers_after_render() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_set_menu_pointers_enabled(true)
	_sync_menu_trigger_baseline()
	_arm_menu_input_after_release()

func _set_menu_visible(is_visible: bool) -> void:
	_set_menu_pointers_enabled(is_visible)
	if is_visible:
		_sync_menu_trigger_baseline()
	if _presenter == null:
		return
	if is_visible:
		_presenter.visible = true
	else:
		_presenter.hide_menu()

func _refresh_menu_pointers() -> void:
	if _player == null:
		return
	for controller_name in ["LeftHandController", "RightHandController"]:
		var pointer := _player.get_node_or_null(NodePath("%s/MenuPointer" % controller_name)) as XRToolsFunctionPointer
		if pointer == null:
			continue
		pointer.process_mode = Node.PROCESS_MODE_ALWAYS
		pointer.enabled = true
		if pointer.has_method("reset_pointer_state"):
			pointer.reset_pointer_state()
		var ray := pointer.get_node_or_null("RayCast") as RayCast3D
		if ray:
			ray.enabled = true
			ray.force_raycast_update()

func _hold_menu_pointers() -> void:
	if _player == null:
		return
	for controller_name in ["LeftHandController", "RightHandController"]:
		var pointer := _player.get_node_or_null(NodePath("%s/MenuPointer" % controller_name)) as XRToolsFunctionPointer
		if pointer == null:
			continue
		pointer.process_mode = Node.PROCESS_MODE_ALWAYS
		pointer.show_laser = XRToolsFunctionPointer.LaserShow.SHOW
		pointer.enabled = true
		var laser := pointer.get_node_or_null("Laser") as MeshInstance3D
		if laser:
			laser.visible = true
		var ray := pointer.get_node_or_null("RayCast") as RayCast3D
		if ray:
			ray.enabled = true

func _set_menu_pointers_enabled(enabled: bool) -> void:
	if _player == null:
		return
	for controller_name in ["LeftHandController", "RightHandController"]:
		var pointer := _player.get_node_or_null(NodePath("%s/MenuPointer" % controller_name)) as XRToolsFunctionPointer
		if pointer:
			pointer.process_mode = Node.PROCESS_MODE_ALWAYS if enabled else Node.PROCESS_MODE_INHERIT
			# COLLIDE hides the beam until the ray hits. The results collider wakes
			# a frame late, so the beam has to be visible as soon as the menu is.
			pointer.show_laser = XRToolsFunctionPointer.LaserShow.SHOW if enabled else XRToolsFunctionPointer.LaserShow.COLLIDE
			if enabled and pointer.has_method("reset_pointer_state"):
				pointer.reset_pointer_state()
			pointer.enabled = enabled
