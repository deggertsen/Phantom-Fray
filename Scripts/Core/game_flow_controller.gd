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
## The world front: pick a city.
const STATE_WORLD := &"world"
## One section of a city: pick a district and deploy.
const STATE_CITY := &"city"
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
## The operation unlocked after the round, for results to offer next; "" when there is none.
var _next_mission_id: String = ""
## How many sites were sealed before the round, so results can show the front moving.
var _sealed_before: int = -1
## The site picked on the city map. Deploy starts it; "" falls back to the next live site.
var _selected_site_id: String = ""
## The world map's difficulty filter ("all", "easy", "medium", "hard") and the city it has picked.
var _world_filter: String = "all"
var _selected_city_id: String = ""
## The region the world map is zoomed to, "" for the whole world. Kept across a city's section,
## so the way back lands where the player left.
var _world_region_id: String = ""
## The city the map is closing in on before its section opens; menu actions wait for it.
var _opening_city_id: String = ""
## The next world map starts zoomed in on this city and eases out to the region.
var _zoom_from_city_id: String = ""
## The district picked on the city map; "" picks the first open one.
var _selected_node_id: String = ""
## What the last world mission did to the war, for results: see _finish_world_mission.
var _world_result: Dictionary = {}
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
##   adb shell "run-as com.phantomfury.resonancerising sh -c 'echo --mission=sweep_drill > files/debug_args.txt'"
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
	if _state == STATE_WORLD and _opening_city_id != "":
		return
	_menu_action_cooldown = 0.45
	if _state != STATE_RESULTS:
		if not _menu_input_armed:
			return
		_menu_input_armed = false
		get_tree().create_timer(0.25).timeout.connect(_arm_menu_input_after_release)
	if String(action).begins_with("site_"):
		var site_id := String(action).trim_prefix("site_")
		if MissionCatalog.is_unlocked(site_id, _settings):
			_selected_site_id = site_id
		_show_main_menu()
		return
	if String(action).begins_with("tier_"):
		if _settings:
			_settings.set_difficulty_tier(String(action).trim_prefix("tier_"))
		_show_main_menu()
		return
	if String(action).begins_with("world_city_"):
		_selected_city_id = String(action).trim_prefix("world_city_")
		_show_world_map()
		return
	if String(action).begins_with("world_filter_"):
		_world_filter = String(action).trim_prefix("world_filter_")
		_show_world_map()
		return
	if String(action).begins_with("world_region_"):
		_world_region_id = String(action).trim_prefix("world_region_")
		if WorldMap.region_of(_selected_city_id) != _world_region_id:
			_selected_city_id = _region_pick(WorldMap.city_entries(_settings), _world_region_id)
		_show_world_map()
		return
	if String(action).begins_with("node_"):
		_selected_node_id = String(action).trim_prefix("node_")
		_show_city_operations()
		return
	match action:
		&"deploy":
			if _state == STATE_CITY:
				_start_world_mission()
			else:
				_start_mission(_selected_site_id)
		&"world", &"world_back":
			_world_region_id = ""
			_show_world_map()
		&"city_world":
			_zoom_from_city_id = _selected_city_id
			_show_world_map()
		&"world_open":
			_selected_node_id = ""
			_open_selected_city()
		&"results_world", &"results_city":
			if _results_action_locked:
				return
			_results_action_locked = true
			_leave_results()
			_selected_node_id = ""
			if action == &"results_world":
				_show_world_map()
			else:
				_show_city_operations()
			_menu_input_armed = false
			_sync_menu_trigger_baseline()
			_arm_menu_input_after_release()
		&"campaign":
			_show_main_menu()
		&"assist_on", &"assist_off":
			if _settings:
				_settings.set_world_assist(action == &"assist_on")
			_show_city_operations()
		&"training":
			_start_training()
		&"results_training":
			if _results_action_locked:
				return
			_results_action_locked = true
			_start_training()
		&"settings":
			_show_settings(_state if _state in [STATE_WORLD, STATE_CITY] else STATE_MENU)
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
			elif _previous_state == STATE_WORLD:
				_show_world_map()
			elif _previous_state == STATE_CITY:
				_show_city_operations()
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
				_return_to_city_map()
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
		if controller and _trigger_down(controller):
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
				elif _state == STATE_CITY:
					_zoom_from_city_id = _selected_city_id
					_show_world_map()
				elif _state == STATE_WORLD and _world_region_id != "":
					_world_region_id = ""
					_show_world_map()
				elif _state == STATE_WORLD:
					_show_main_menu()
				elif _state in [STATE_SETTINGS, STATE_RESULTS] and not _paused_training:
					_show_main_menu()

## The main menu is the breach city: pick a site and a difficulty, then deploy.
func _show_main_menu() -> void:
	_state = STATE_MENU
	_set_menu_visible(true)
	if _selected_site_id == "" or not MissionCatalog.is_unlocked(_selected_site_id, _settings):
		_selected_site_id = MissionCatalog.next_unlocked_id(_settings)
	if _presenter:
		var training_first: bool = _settings != null and not _settings.tutorial_completed
		_presenter.show_city_map(MissionCatalog.operation_entries(_settings), _selected_site_id, MissionCatalog.tier_from(_settings), training_first)

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
	_apply_site(String(mission.get("site", WorldMap.DEFAULT_SITE)))
	_state = STATE_PLAYING
	_set_menu_visible(false)
	if _round:
		_round.begin_round(mission, _active_tier)

# --- World map ------------------------------------------------------------------------------

func _show_world_map() -> void:
	_state = STATE_WORLD
	_set_menu_visible(true)
	var entries := WorldMap.city_entries(_settings)
	_opening_city_id = ""
	if _selected_city_id == "" or WorldMap.city(_selected_city_id).is_empty():
		_selected_city_id = WorldMap.home_city_id()
	if _world_region_id != "" and WorldMap.region(_world_region_id).is_empty():
		_world_region_id = ""
	var world := _world_status(entries)
	_zoom_from_city_id = ""
	if _presenter:
		_presenter.show_world_map(world, entries, _selected_city_id)

## What the world panels need beyond the entries: see VRWrapPanel.show_world_status.
func _world_status(entries: Array[Dictionary]) -> Dictionary:
	return {
		"liberation": WorldMap.world_liberation(_settings),
		"filter": _world_filter,
		"home_id": WorldMap.home_city_id(),
		"priority": _world_priority(entries),
		"training_first": _settings != null and not _settings.tutorial_completed,
		"assist": _settings != null and _settings.world_assist,
		"region": _world_region_id,
		"zoom_from": _zoom_from_city_id,
	}

## The city a region opens on when the picked one is elsewhere: home, then the most fought-over
## city still in reach, then the first.
func _region_pick(entries: Array[Dictionary], region_id: String) -> String:
	var members: Array = WorldMap.region(region_id).get("cities", [])
	var best: Dictionary = {}
	var rank := {WorldMap.STATE_OVERRUN: 3, WorldMap.STATE_DANGER: 2, WorldMap.STATE_THREATENED: 1}
	for entry in entries:
		if not entry.get("id", "") in members:
			continue
		if entry.get("id", "") == WorldMap.home_city_id():
			return String(entry["id"])
		var score := int(rank.get(String(entry.get("state", "")), 0)) if not entry.get("liberated", false) else 0
		if best.is_empty() or score > int(best["score"]):
			best = {"id": entry["id"], "score": score}
	return String(best.get("id", _selected_city_id))

## Open on the city card: the map closes in on the city, then its section takes the panels.
## Anything that leaves the world map meanwhile (Back, Escape, a recenter) cancels the open.
func _open_selected_city() -> void:
	var city_id := _selected_city_id
	var entry := WorldMap.city_entry(_settings, city_id)
	if entry.is_empty() or not entry.get("playable", false) or _presenter == null or not _presenter.zoom_world_to_city(city_id):
		_show_city_operations()
		return
	_opening_city_id = city_id
	await _presenter.world_zoom_settled
	if _opening_city_id != city_id:
		return
	_opening_city_id = ""
	if _state == STATE_WORLD:
		_show_city_operations()

## Chen's priority: the home city while it has missions, otherwise the overrun city closest to
## being liberated, otherwise whatever is playable. {} when the war offers nothing.
func _world_priority(entries: Array[Dictionary]) -> Dictionary:
	var home_id := WorldMap.home_city_id()
	var best: Dictionary = {}
	for entry in entries:
		if not entry.get("playable", false) or entry.get("liberated", false):
			continue
		if entry.get("id", "") == home_id:
			best = entry
			break
		if best.is_empty():
			best = entry
			continue
		var closer := String(entry.get("state", "")) == WorldMap.STATE_OVERRUN and String(best.get("state", "")) != WorldMap.STATE_OVERRUN
		var further := int(entry.get("liberation", 0)) > int(best.get("liberation", 0)) and String(entry.get("state", "")) == String(best.get("state", ""))
		if closer or further:
			best = entry
	if best.is_empty():
		return {}
	var body := ""
	if best.get("id", "") == home_id:
		body = "%s. The front is about %d km out and it does not stop. Hold home ground." % [best.get("name", ""), WorldMap.kilometers(float(best.get("distance", 0.0)))]
	else:
		body = "%s is %s at %d%% liberated. Every operation there pushes the line back." % [best.get("name", ""), String(best.get("state_label", "")).to_lower(), int(best.get("liberation", 0))]
	return {"city_id": best.get("id", ""), "body": body, "bonus": "%s  •  %s" % [best.get("difficulty_label", ""), best.get("resistance", "")]}

## The picked city's current section. Falls back to the world map for a city with no missions.
func _show_city_operations() -> void:
	var entry := WorldMap.city_entry(_settings, _selected_city_id)
	if entry.is_empty() or not entry.get("playable", false):
		_show_world_map()
		return
	_state = STATE_CITY
	_set_menu_visible(true)
	if _presenter:
		_presenter.show_city_operations(_city_status(entry))

## What the city panels need: see VRWrapPanel.show_operations_status.
func _city_status(entry: Dictionary) -> Dictionary:
	var section := WorldMap.section(String(entry["id"]), int(entry.get("section", 0)))
	var sealed: Array = entry.get("sealed", [])
	var open := WorldMap.available_nodes(section, sealed)
	if _selected_node_id == "" or WorldMap.node_in(section, _selected_node_id).is_empty():
		_selected_node_id = open[0] if not open.is_empty() else ""
	var node := WorldMap.node_in(section, _selected_node_id)
	var assist: bool = _settings != null and _settings.world_assist
	var tier := WorldMap.tier_for(String(entry.get("state", "")), assist)
	var kind := String(node.get("kind", WorldMap.KIND_SINGLE))
	var mission := WorldMap.build_mission(entry, int(entry.get("section", 0)), node, tier) if not node.is_empty() else {}
	return {
		"entry": entry,
		"section": section,
		"sealed": sealed,
		"selected_id": _selected_node_id,
		"tier": tier,
		"assist": assist,
		"node": node,
		"status": WorldMap.node_status(section, sealed, _selected_node_id) if not node.is_empty() else "locked",
		"kind_label": WorldMap.kind_label(kind, tier),
		"kind_summary": WorldMap.kind_summary(kind, tier),
		"expected_minutes": DifficultyTier.apply_mission(mission, tier).get("expected_minutes", []) if not mission.is_empty() else [],
		"best_seconds": _settings.best_time(_world_record_id(String(entry["id"]), kind), tier) if _settings else 0.0,
	}

## Best scores and times for the world are kept per city, district kind, and tier.
func _world_record_id(city_id: String, kind: String) -> String:
	return "world:%s:%s" % [city_id, kind]

## Deploys the picked district of the picked city at the city's tier.
func _start_world_mission() -> void:
	var entry := WorldMap.city_entry(_settings, _selected_city_id)
	if entry.is_empty() or not entry.get("playable", false):
		_show_world_map()
		return
	var mission := _world_mission(WorldMap.mission_id(String(entry["id"]), int(entry.get("section", 0)), _selected_node_id))
	if mission.is_empty():
		_show_city_operations()
		return
	_active_mission_id = String(mission["id"])
	_active_tier = WorldMap.tier_for(String(entry.get("state", "")), _settings != null and _settings.world_assist)
	_debug_run = false
	_apply_site(String(mission.get("site", WorldMap.DEFAULT_SITE)))
	_state = STATE_PLAYING
	_set_menu_visible(false)
	if _round:
		_round.begin_round(mission, _active_tier)

## The mission for a world mission id, or {} when its district is not open to deploy.
func _world_mission(mission_id: String) -> Dictionary:
	var parsed := WorldMap.parse_mission_id(mission_id)
	if parsed.is_empty():
		return {}
	var entry := WorldMap.city_entry(_settings, String(parsed["city_id"]))
	if entry.is_empty() or not entry.get("playable", false) or int(entry.get("section", 0)) != int(parsed["section"]):
		return {}
	var section := WorldMap.section(String(entry["id"]), int(parsed["section"]))
	var node := WorldMap.node_in(section, String(parsed["node_id"]))
	if node.is_empty() or WorldMap.node_status(section, entry.get("sealed", []), String(parsed["node_id"])) != "open":
		return {}
	var tier := WorldMap.tier_for(String(entry.get("state", "")), _settings != null and _settings.world_assist)
	return WorldMap.build_mission(entry, int(parsed["section"]), node, tier)

## Dresses the arena for a breach site or district before a deploy. ArenaPresentation decides
## what the id means and falls back to the Dead City; nothing happens without that method.
func _apply_site(site_id: String) -> void:
	var arena := get_tree().get_first_node_in_group("ArenaPresentation")
	if arena and arena.has_method("apply_site"):
		arena.call("apply_site", site_id)

## Records a world mission's victory and credits the seal. Returns the report's "world" block.
func _finish_world_mission(victory: bool, score: int) -> Dictionary:
	var parsed := WorldMap.parse_mission_id(_active_mission_id)
	if parsed.is_empty():
		return {}
	var city_id := String(parsed["city_id"])
	var before := WorldMap.city_entry(_settings, city_id)
	var section := WorldMap.section(city_id, int(parsed["section"]))
	var node := WorldMap.node_in(section, String(parsed["node_id"]))
	var kind := String(node.get("kind", WorldMap.KIND_SINGLE))
	var sealed_before: Array = Array(before.get("sealed", [])).duplicate()
	var result := {"operation_complete": false, "sealed": sealed_before}
	if victory and _settings and int(before.get("section", 0)) == int(parsed["section"]):
		_previous_best_time = _settings.best_time(_world_record_id(city_id, kind), _active_tier)
		_settings.record_score(_world_record_id(city_id, kind), score, _active_tier)
		_settings.record_time(_world_record_id(city_id, kind), _last_seconds, _active_tier)
		result = WorldMap.seal_node(_settings, city_id, String(parsed["node_id"]))
	var after := WorldMap.city_entry(_settings, city_id)
	return {
		"entry": after,
		"section": section,
		"sealed_before": sealed_before,
		"sealed_after": result.get("sealed", sealed_before),
		"node": node,
		"kind_label": WorldMap.kind_label(kind, _active_tier),
		"operation_complete": result.get("operation_complete", false),
		"liberation_before": before.get("liberation", 0),
		"liberation_after": after.get("liberation", 0),
	}

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
		STATE_WORLD:
			_show_world_map()
		STATE_CITY:
			_show_city_operations()
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

## The Meta recenter, after XRLifecycleController has moved the play space under the head.
func recenter_current_panel() -> void:
	if _presenter:
		_presenter.recenter_on_play_space()

func _on_round_finished(outcome: StringName, score: int) -> void:
	# Training ends through its director, after Chen signs off.
	if _round and bool(_round.current_mission().get("tutorial", false)):
		return
	_last_outcome = outcome
	_last_score = score
	_last_debrief = _round.get_debrief(outcome) if _round else ""
	_last_seconds = _round.elapsed_seconds if _round else 0.0
	_previous_best_time = 0.0
	_next_mission_id = ""
	_sealed_before = -1
	_world_result = {}
	if WorldMap.is_world_mission(_active_mission_id):
		_world_result = _finish_world_mission(outcome == &"victory", score)
	# A debug drill or shortcut is not campaign progress, so it records no clear, score, or time.
	# Records are kept per tier; a clear at any tier unlocks the next operation.
	elif outcome == &"victory" and _settings and not _debug_run and not MissionCatalog.is_debug_mission(_active_mission_id):
		_sealed_before = _settings.cleared_missions.size()
		_previous_best_time = _settings.best_time(_active_mission_id, _active_tier)
		_settings.mark_mission_cleared(_active_mission_id)
		_settings.record_score(_active_mission_id, score, _active_tier)
		_settings.record_time(_active_mission_id, _last_seconds, _active_tier)
		_next_mission_id = MissionCatalog.unlocked_followup(_active_mission_id, _settings)
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
		_presenter.show_results(_results_report())
	_refresh_menu_pointers()
	call_deferred("_reset_results_pointers_after_render")

## What the results panels show. The city entries are after the round; the mission and the next
## site carry their expected times at the tier the round was played at, which Retry and Next keep.
func _results_report() -> Dictionary:
	if not _world_result.is_empty():
		var world_node: Dictionary = _world_result.get("node", {})
		var city_id := String((_world_result.get("entry", {}) as Dictionary).get("id", ""))
		var kind := String(world_node.get("kind", WorldMap.KIND_SINGLE))
		return {
			"outcome": _last_outcome,
			"score": _last_score,
			"debrief": _last_debrief,
			"seconds": _last_seconds,
			"previous_best": _previous_best_time,
			"best_seconds": _settings.best_time(_world_record_id(city_id, kind), _active_tier) if _settings else 0.0,
			"tier": _active_tier,
			"world": _world_result,
			"offer_training": _last_outcome == &"defeat",
		}
	var entries := MissionCatalog.operation_entries(_settings)
	return {
		"outcome": _last_outcome,
		"score": _last_score,
		"debrief": _last_debrief,
		"seconds": _last_seconds,
		"previous_best": _previous_best_time,
		"best_seconds": _settings.best_time(_active_mission_id, _active_tier) if _settings else 0.0,
		"tier": _active_tier,
		"mission": _tiered_entry(entries, _active_mission_id),
		"next": _tiered_entry(entries, _next_mission_id) if _next_mission_id != "" else {},
		"sealed_before": _sealed_before,
		"entries": entries,
		"offer_training": _last_outcome == &"defeat",
	}

## The city entry for a mission (a debug drill has none, so it is built from the catalog), with
## its expected time at the active tier.
func _tiered_entry(entries: Array[Dictionary], mission_id: String) -> Dictionary:
	var mission := MissionCatalog.get_mission(mission_id)
	var entry: Dictionary = {"id": mission_id, "title": mission.get("title", ""), "summary": mission.get("summary", "")}
	for candidate in entries:
		if candidate.get("id", "") == mission_id:
			entry = candidate.duplicate()
	entry["expected_minutes"] = DifficultyTier.apply_mission(mission, _active_tier).get("expected_minutes", [])
	return entry

## The trigger, or a pinch while that hand's controller hangs on its strap (CombatHandController).
func _trigger_down(controller: XRController3D) -> bool:
	var combat := controller as CombatHandController
	if combat:
		return combat.is_menu_trigger_down()
	return controller.is_button_pressed("trigger_click")

func _poll_menu_trigger() -> void:
	if _player == null or _presenter == null or not _presenter.is_menu_visible() or _state in [STATE_PLAYING, STATE_TRAINING]:
		_menu_trigger_down = false
		return
	var down := false
	var held: XRController3D = null
	for path in [NodePath("LeftHandController"), NodePath("RightHandController")]:
		var controller := _player.get_node_or_null(path) as XRController3D
		if controller and _trigger_down(controller):
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
			return action in [&"retry", &"next_mission", &"results_menu", &"results_training", &"results_city", &"results_world"]
		STATE_WORLD:
			return String(action).begins_with("world_city_") or String(action).begins_with("world_filter_") or String(action).begins_with("world_region_") or action in [&"world_open", &"world_back", &"campaign", &"training", &"settings"]
		STATE_CITY:
			return String(action).begins_with("node_") or action in [&"deploy", &"city_world", &"assist_on", &"assist_off", &"settings"]
		STATE_SETTINGS:
			return action in [&"music_down", &"music_up", &"effects_down", &"effects_up", &"haptics_down", &"haptics_up", &"own_music_off", &"own_music_on", &"settings_flashes_off", &"settings_flashes_on", &"reset_progress", &"settings_back"]
		STATE_RESET_CONFIRM:
			return action in [&"reset_cancel", &"reset_confirm"]
		STATE_MENU:
			return String(action).begins_with("site_") or String(action).begins_with("tier_") or action in [&"deploy", &"training", &"settings", &"world"]
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
		if controller and _trigger_down(controller):
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
	_presenter.activate_on_body(body, hit)

func _restart_mission(mission_id: String) -> void:
	if WorldMap.is_world_mission(mission_id):
		# Replay after a seal reopens nothing: the district is sealed, so the city map takes over.
		var world_mission := _world_mission(mission_id)
		if world_mission.is_empty() or _round == null:
			_results_action_locked = false
			_selected_node_id = ""
			_show_city_operations()
			return
		_active_mission_id = mission_id
		_round.abandon_round()
		_state = STATE_PLAYING
		_set_menu_visible(false)
		_round.begin_round(world_mission, _active_tier)
		return
	var mission := MissionCatalog.get_mission(mission_id)
	if mission.is_empty() or _round == null or not (_debug_run or MissionCatalog.is_unlocked(mission_id, _settings)):
		_results_action_locked = false
		_return_to_city_map()
		return
	# Retry and Next keep the tier the last mission was played at.
	_active_mission_id = mission_id
	_round.abandon_round()
	_state = STATE_PLAYING
	_set_menu_visible(false)
	_round.begin_round(mission, _active_tier)

## Leaving results for a menu: the round is dropped and the lock lifts for the next results.
func _leave_results() -> void:
	if _round:
		_round.abandon_round()
	_results_action_locked = false

## Back from results, the map selects the next live site again, which a clear may have just opened.
func _return_to_city_map() -> void:
	_leave_results()
	_selected_site_id = ""
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
