extends Node

const STATE_MENU := &"menu"
## The Training Complete panel, in the chamber.
const STATE_TUTORIAL := &"tutorial"
## Chen's training chamber is running; the menu is hidden.
const STATE_TRAINING := &"training"
const STATE_PLAYING := &"playing"
const STATE_PAUSED := &"paused"
const STATE_SETTINGS := &"settings"
const STATE_RESULTS := &"results"
const STATE_ABORT_CONFIRM := &"abort_confirm"
const STATE_RESET_CONFIRM := &"reset_confirm"
## Debug builds: --mission=the_maw_boss, like B in the main menu, deploys The Maw at Full Resonance.
const BOSS_SHORTCUT := "the_maw_boss"

var _state: StringName = STATE_MENU
var _previous_state: StringName = STATE_MENU
var _round: RoundController
var _player: Node3D
var _presenter: VRMenuPresenter
var _tutorial: TutorialDirector
## The pause menu is up over training, not over an operation.
var _paused_training: bool = false
var _settings: Node
var _last_outcome: StringName = &""
var _last_score: int = 0
var _last_seconds: float = 0.0
## The mission's fastest stored victory before the round that just finished, so results can call a new best.
var _previous_best_time: float = 0.0
var _active_mission_id: String = ""
## The difficulty the active mission plays at, and whether it is a debug shortcut that records nothing.
var _active_tier: String = DifficultyTier.STANDARD
var _debug_run: bool = false
## Debug builds: --tier=<id> plays command-line deploys at that tier without changing the saved choice.
var _command_tier: String = ""
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
	_tutorial = get_tree().get_first_node_in_group("TutorialDirector") as TutorialDirector
	if _tutorial:
		_tutorial.finished.connect(_on_training_finished)
	if _round:
		_round.round_finished.connect(_on_round_finished)
	if _presenter:
		_presenter.action_requested.connect(_on_menu_action)
	_connect_controller_buttons()
	var pending := ""
	if _settings:
		pending = String(_settings.pending_mission_id)
		_settings.pending_mission_id = ""
	if pending == "" and OS.is_debug_build():
		pending = _mission_from_command_line()
	if pending == BOSS_SHORTCUT:
		_start_boss_shortcut()
	elif pending != "" and not MissionCatalog.get_mission(pending).is_empty():
		_start_mission(pending, _command_tier)
	else:
		_show_main_menu()
		_arm_menu_input_after_release()

## Debug builds: --mission=<id> skips the menu and deploys straight into that operation, including
## the debug-only ones in MissionCatalog.debug_missions(). On Quest, put it in the Quest Debug
## export preset's Command Line > Extra Args. --maw-breaks makes every boss Maw break.
## --tier=<id> picks the difficulty (assist, standard, operator, full_resonance) for that deploy.
## --mission=the_maw_boss is the B shortcut: The Maw at Full Resonance, whatever is unlocked.
func _mission_from_command_line() -> String:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args() + _debug_args_file()
	for arg in args:
		if arg == "--maw-breaks":
			MawBoss.always_break = true
		elif arg.begins_with("--tier="):
			_command_tier = DifficultyTier.resolve(arg.trim_prefix("--tier="))
	for arg in args:
		if arg.begins_with("--mission="):
			return arg.trim_prefix("--mission=")
	return ""

## Debug builds also read arguments from user://debug_args.txt, because Quest launches cannot
## pass them: the exported launcher activity drops intent extras on its way to GodotApp, and
## GodotApp itself is not exported. A debuggable build lets adb write the file:
##   adb shell "run-as com.phantomfray.resonancerising sh -c 'echo --mission=sweep_drill > files/debug_args.txt'"
## Delete the file (or write an empty one) to boot to the menu again.
func _debug_args_file() -> PackedStringArray:
	if not OS.is_debug_build() or not FileAccess.file_exists("user://debug_args.txt"):
		return PackedStringArray()
	var text := FileAccess.get_file_as_string("user://debug_args.txt")
	return text.strip_edges().split(" ", false)

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
	elif button == "menu_button" and _state == STATE_TRAINING:
		_pause_training()

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
	if String(action).begins_with("tier_"):
		if _settings:
			_settings.set_difficulty_tier(String(action).trim_prefix("tier_"))
		_show_operations()
		return
	match action:
		&"deploy":
			_start_mission("")
		&"operations":
			_show_operations()
		&"operations_back":
			_show_main_menu()
		&"training":
			_start_training()
		&"results_training":
			if _results_action_locked:
				return
			_results_action_locked = true
			_start_training()
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
		&"own_music_off", &"own_music_on":
			if _settings:
				_settings.set_own_music(action == &"own_music_on")
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
		&"training_deploy":
			if _tutorial:
				_tutorial.stop()
			_start_mission("")
		&"training_replay":
			_start_training()
		&"training_menu":
			if _tutorial:
				_tutorial.stop()
			_show_main_menu()
		&"end_training":
			_end_training()
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
					_on_menu_action(&"training_deploy")
				elif _state == STATE_TRAINING and OS.is_debug_build() and _tutorial:
					# Desktop stand-in for squeezing both grips.
					_tutorial.confirm()
				elif _state == STATE_PAUSED:
					_on_menu_action(&"resume")
			KEY_T:
				_on_menu_action(&"training")
			KEY_B:
				# Debug builds only: The Maw at Full Resonance, whatever is unlocked. Shift forces a break.
				if OS.is_debug_build() and _state == STATE_MENU:
					MawBoss.force_next_break = event.shift_pressed
					_start_boss_shortcut()
			KEY_P:
				# Debug builds only: one push-up, until push-up detection exists.
				if OS.is_debug_build() and _state == STATE_PLAYING:
					var boss := get_tree().get_first_node_in_group("MawBoss") as MawBoss
					if boss:
						boss.register_push_up()
			KEY_S:
				# Not over a running simulation; pause it first.
				if _state != STATE_TRAINING:
					_show_settings(_state)
			KEY_ESCAPE:
				if _state == STATE_PLAYING:
					_pause_game()
				elif _state == STATE_TRAINING:
					_pause_training()
				elif _state == STATE_TUTORIAL:
					_on_menu_action(&"training_menu")
				elif _state in [STATE_SETTINGS, STATE_RESULTS] and not _paused_training:
					_show_main_menu()

func _show_main_menu() -> void:
	_state = STATE_MENU
	_set_menu_visible(true)
	if _presenter:
		var training_first: bool = _settings != null and not _settings.tutorial_completed
		_presenter.show_main_menu(MissionCatalog.deploy_detail(_settings), training_first)

func _show_operations() -> void:
	_state = STATE_MENU
	_set_menu_visible(true)
	if _presenter:
		_presenter.show_operations(MissionCatalog.operation_entries(_settings), MissionCatalog.tier_from(_settings))

## Deploys a mission at the chosen difficulty, or at `tier_override` when one is given.
## A debug run skips the unlock chain and records nothing.
func _start_mission(mission_id: String = "", tier_override: String = "", debug_run: bool = false) -> void:
	var resolved_id := mission_id if mission_id != "" else MissionCatalog.next_unlocked_id(_settings)
	var mission := MissionCatalog.get_mission(resolved_id)
	if mission.is_empty() or not (debug_run or MissionCatalog.is_unlocked(resolved_id, _settings)):
		_show_main_menu()
		return
	_active_mission_id = resolved_id
	if tier_override != "":
		_active_tier = DifficultyTier.resolve(tier_override)
	elif MissionCatalog.is_debug_mission(resolved_id):
		# A drill plays as authored unless --tier says otherwise.
		_active_tier = DifficultyTier.STANDARD
	else:
		_active_tier = MissionCatalog.tier_from(_settings)
	_debug_run = debug_run
	_state = STATE_PLAYING
	_set_menu_visible(false)
	if _round:
		_round.begin_round(mission, _active_tier)

## Debug builds: The Maw at Full Resonance, straight from the menu (B) or the command line
## (--mission=the_maw_boss). It replaces the old debug-only boss mission, so like a drill it
## records no clear, score, or time, though its break counts toward the break odds.
func _start_boss_shortcut() -> void:
	if not OS.is_debug_build():
		_show_main_menu()
		return
	_start_mission("the_maw", DifficultyTier.FULL_RESONANCE, true)

## Chen's training chamber, from the top. The menu hides; the director runs the beats.
func _start_training() -> void:
	if _tutorial == null:
		return
	_paused_training = false
	if _round:
		_round.abandon_round()
	_state = STATE_TRAINING
	_set_menu_visible(false)
	_tutorial.start()

## Chen signed off. The panel comes up in the chamber; leaving it turns the chamber off.
func _on_training_finished() -> void:
	if _round:
		_round.abandon_round()
	_state = STATE_TUTORIAL
	_menu_input_armed = false
	_render_training_complete()
	_arm_menu_input_after_release()

func _render_training_complete() -> void:
	_set_menu_visible(true)
	if _presenter:
		_presenter.show_training_complete(MissionCatalog.deploy_detail(_settings))

## End Training from pause. Nobody is made to sit through all of it: ending counts as done.
func _end_training() -> void:
	_paused_training = false
	if _tutorial:
		_tutorial.stop()
	if _round:
		_round.abandon_round()
	_mark_training_complete()
	_show_main_menu()

func _mark_training_complete() -> void:
	if _settings:
		_settings.tutorial_completed = true
		_settings.save_settings()

func is_training() -> bool:
	return _state == STATE_TRAINING or (_state in [STATE_PAUSED, STATE_SETTINGS] and _paused_training)

func _pause_training() -> void:
	_paused_training = true
	_state = STATE_PAUSED
	if _tutorial:
		_tutorial.set_paused(true)
	if _round and _round.is_round_in_progress():
		_round.pause_round()
	_show_pause_menu()

func _pause_game() -> void:
	_state = STATE_PAUSED
	if _round:
		_round.pause_round()
	_show_pause_menu()

## The headset came off or lost focus. The lifecycle controller has already paused a live round.
func show_suspended_pause() -> void:
	if _state == STATE_TRAINING:
		_paused_training = true
		if _tutorial:
			_tutorial.set_paused(true)
		if _round and _round.is_round_in_progress():
			_round.pause_round()
	_state = STATE_PAUSED
	_set_menu_visible(true)
	if _presenter:
		_presenter.show_suspended()

func _show_pause_menu() -> void:
	_state = STATE_PAUSED
	_set_menu_visible(true)
	if _presenter:
		_presenter.show_pause(_paused_training)

func _resume_game() -> void:
	if _paused_training:
		_paused_training = false
		_state = STATE_TRAINING
		_set_menu_visible(false)
		if _round and _round.can_resume_round():
			_round.resume_round()
		if _tutorial:
			_tutorial.set_paused(false)
		return
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
	var own_music := false
	if _settings:
		music = _settings.volume_label(_settings.music_db)
		effects = _settings.volume_label(_settings.sfx_db)
		haptics = "%d%%" % int(_settings.haptic_scale * 100.0)
		reduced_flashes = _settings.reduced_flashes
		own_music = _settings.own_music
	if _presenter:
		_presenter.show_settings(music, effects, haptics, reduced_flashes, _previous_state == STATE_PAUSED, own_music)

func restore_current_menu() -> void:
	match _state:
		STATE_MENU:
			_show_main_menu()
		STATE_TUTORIAL:
			_render_training_complete()
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
	# Training ends through its director, after Chen signs off.
	if _round and bool(_round.current_mission().get("tutorial", false)):
		return
	_last_outcome = outcome
	_last_score = score
	_last_debrief = _round.get_debrief(outcome) if _round else ""
	_last_seconds = _round.elapsed_seconds if _round else 0.0
	_previous_best_time = 0.0
	_next_mission_title = ""
	# A debug drill or shortcut is not campaign progress, so it records no clear, score, or time.
	# Records are kept per tier; a clear at any tier unlocks the next operation.
	if outcome == &"victory" and _settings and not _debug_run and not MissionCatalog.is_debug_mission(_active_mission_id):
		_previous_best_time = _settings.best_time(_active_mission_id, _active_tier)
		_settings.mark_mission_cleared(_active_mission_id)
		_settings.record_score(_active_mission_id, score, _active_tier)
		_settings.record_time(_active_mission_id, _last_seconds, _active_tier)
		var follow_id := MissionCatalog.unlocked_followup(_active_mission_id, _settings)
		if follow_id != "":
			var follow := MissionCatalog.get_mission(follow_id)
			_next_mission_title = "%s  •  %s" % [follow.get("title", ""), MissionCatalog.expected_minutes_text(DifficultyTier.apply_mission(follow, _active_tier))]
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
		_presenter.show_results(_last_outcome, _last_score, _last_debrief, _next_mission_title, _last_seconds, _previous_best_time, DifficultyTier.label(_active_tier), _last_outcome == &"defeat")
	_refresh_menu_pointers()
	call_deferred("_reset_results_pointers_after_render")

func _poll_menu_trigger() -> void:
	if _player == null or _presenter == null or not _presenter.is_menu_visible() or _state in [STATE_PLAYING, STATE_TRAINING]:
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
			return action in [&"retry", &"next_mission", &"results_menu", &"results_training"]
		STATE_SETTINGS:
			return action in [&"music_down", &"music_up", &"effects_down", &"effects_up", &"haptics_down", &"haptics_up", &"own_music_off", &"own_music_on", &"settings_flashes_off", &"settings_flashes_on", &"reset_progress", &"settings_back"]
		STATE_RESET_CONFIRM:
			return action in [&"reset_cancel", &"reset_confirm"]
		STATE_MENU:
			return String(action).begins_with("mission_") or String(action).begins_with("tier_") or action in [&"deploy", &"operations", &"operations_back", &"training", &"settings"]
		STATE_TUTORIAL:
			return action in [&"training_deploy", &"training_replay", &"training_menu"]
		STATE_PAUSED:
			if _paused_training:
				return action in [&"resume", &"pause_settings", &"end_training"]
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
	if mission.is_empty() or _round == null or not (_debug_run or MissionCatalog.is_unlocked(mission_id, _settings)):
		_results_action_locked = false
		_return_to_operations_menu()
		return
	# Retry and Next keep the tier the last mission was played at.
	_active_mission_id = mission_id
	_round.abandon_round()
	_state = STATE_PLAYING
	_set_menu_visible(false)
	_round.begin_round(mission, _active_tier)

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
