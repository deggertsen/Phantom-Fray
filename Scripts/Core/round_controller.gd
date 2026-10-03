extends Node
class_name RoundController

signal score_changed(total: int, delta: int, reason: StringName)
signal combo_changed(streak: int, multiplier: float)
signal rift_progress_changed(closed: int, total: int)
signal time_changed(seconds_remaining: float)
signal mission_status_changed(text: String)
signal pressure_changed(ratio: float)
signal round_finished(outcome: StringName, score: int)

@export var round_duration: float = 240.0
@export var countdown_seconds: int = 3
@export var combo_timeout: float = 4.0
@export var maximum_multiplier: float = 3.0

var score: int = 0
var sweet_streak: int = 0
var multiplier: float = 1.0
var seconds_remaining: float
var _last_emitted_second: int = -1
var _combo_remaining: float = 0.0
var _round_active: bool = false
var _countdown_active: bool = false
var _paused: bool = false
var _countdown_remaining: float = 0.0
var _countdown_displayed: int = -1
var _finished: bool = false
var _director: RiftDirector
var _life_force: LifeForceManager
var _player: Node3D
var _message: Label3D
var _mission: Dictionary = {}

func _ready() -> void:
	add_to_group("RoundController")
	seconds_remaining = round_duration
	await get_tree().process_frame
	_director = get_tree().get_first_node_in_group("RiftSpawnManager") as RiftDirector
	_life_force = get_tree().get_first_node_in_group("LifeForceManager") as LifeForceManager
	_player = get_tree().get_first_node_in_group("Player") as Node3D
	if _director == null or _life_force == null:
		push_error("RoundController: required gameplay systems not found")
		return
	_director.phantom_resolved.connect(_on_phantom_resolved)
	_director.player_damaged.connect(_on_player_damaged)
	_director.strike_rejected.connect(_on_strike_rejected)
	_director.rift_closed.connect(_on_rift_closed)
	_director.rift_spawned.connect(_on_rift_spawned)
	_director.all_rifts_closed.connect(_on_all_rifts_closed)
	_life_force.life_force_depleted.connect(_on_life_force_depleted)
	# GameFlowController starts the round after the player selects Deploy.

func is_round_active() -> bool:
	return _round_active

func is_round_in_progress() -> bool:
	return (_round_active or _countdown_active or _paused) and not _finished

func can_resume_round() -> bool:
	return _paused and not _finished

func abandon_round() -> void:
	_finished = false
	_round_active = false
	_countdown_active = false
	_paused = false
	score = 0
	sweet_streak = 0
	multiplier = 1.0
	_combo_remaining = 0.0
	if _director:
		_director.cleanup_round()
	if _life_force:
		_life_force.set_process(true)
		_life_force.reset()
	score_changed.emit(score, 0, &"reset")
	combo_changed.emit(sweet_streak, multiplier)
	rift_progress_changed.emit(0, _director.total_rifts if _director else 0)
	if is_instance_valid(_message):
		_message.queue_free()
	_message = null

func begin_round(mission: Dictionary = {}) -> void:
	if _round_active or _countdown_active or _finished or _director == null:
		return
	_mission = mission
	if mission.has("duration"):
		round_duration = float(mission.get("duration", round_duration))
	seconds_remaining = round_duration
	_last_emitted_second = -1
	_emit_time_if_changed()
	_life_force.reset()
	_countdown_active = true
	_paused = false
	_countdown_remaining = float(countdown_seconds)
	_countdown_displayed = -1

func pause_round() -> void:
	if not is_round_in_progress() or _paused:
		return
	_paused = true
	_round_active = false
	_director.stop_spawning()
	for rift in _director.rift_instances:
		if is_instance_valid(rift):
			rift.set_process(false)
	_life_force.set_process(false)
	for phantom in get_tree().get_nodes_in_group("phantom"):
		if is_instance_valid(phantom):
			phantom.set_physics_process(false)
			phantom.set_process(false)
			if phantom.has_method("set_interactions_enabled"):
				phantom.set_interactions_enabled(false)

func resume_round() -> void:
	if not can_resume_round():
		return
	_paused = false
	_life_force.set_process(true)
	for rift in _director.rift_instances:
		if is_instance_valid(rift):
			rift.set_process(true)
	if _countdown_active:
		return
	_round_active = true
	_director.resume_spawning()
	for phantom in get_tree().get_nodes_in_group("phantom"):
		if is_instance_valid(phantom):
			phantom.set_physics_process(true)
			phantom.set_process(true)
			if phantom.has_method("set_interactions_enabled"):
				phantom.set_interactions_enabled(true)

func _process(delta: float) -> void:
	if _paused or _finished:
		return
	if _countdown_active:
		_countdown_remaining = maxf(_countdown_remaining - delta, 0.0)
		var displayed := ceili(_countdown_remaining)
		if displayed != _countdown_displayed and displayed > 0:
			_countdown_displayed = displayed
			_show_message("MISSION STARTS IN %d" % displayed, Color(0.35, 0.85, 1.0), 0.0)
		if _countdown_remaining <= 0.0:
			_countdown_active = false
			var bark := String(_mission.get("start_line", _mission.get("objective", "CLOSE THE RIFTS")))
			_show_message(bark, Color(0.7, 0.95, 1.0), 1.8)
			_round_active = true
			_director.start_round(_mission)
			_emit_status()
			_emit_pressure()
		return
	if not _round_active:
		return
	seconds_remaining = maxf(seconds_remaining - delta, 0.0)
	_emit_time_if_changed()
	if _combo_remaining > 0.0:
		_combo_remaining -= delta
		if _combo_remaining <= 0.0:
			_reset_combo()
	if seconds_remaining <= 0.0:
		_finish_round(&"timeout")

func _on_phantom_resolved(result: Dictionary) -> void:
	if not _round_active:
		return
	var sweet: bool = result.get("sweet_spot", false)
	var on_beat: bool = result.get("on_beat", false)
	sweet_streak += 1
	var gain := 0.15
	if sweet:
		gain += 0.2
	if on_beat:
		gain += 0.1
	multiplier = minf(multiplier + gain, maximum_multiplier)
	_combo_remaining = combo_timeout
	var base_points: int = result.get("base_score", 0)
	var awarded := int(round(base_points * multiplier))
	score += awarded
	score_changed.emit(score, awarded, result.get("resolution_kind", &"strike"))
	combo_changed.emit(sweet_streak, multiplier)

func _on_player_damaged(amount: float) -> void:
	if not _round_active:
		return
	_reset_combo()
	_life_force.apply_damage(amount)

func _on_strike_rejected(_reason: StringName) -> void:
	if not _round_active:
		return
	_reset_combo()

func _on_rift_spawned(_rift_id: int, _rift: Node3D) -> void:
	if not _round_active or _director == null:
		return
	var index := _director.spawned_rifts - 1
	var barks: Array = _mission.get("open_barks", [])
	if index > 0 and index < barks.size():
		var bark := String(barks[index])
		if bark != "":
			_show_message(bark, Color(1.0, 0.78, 0.35), 1.6)
	_emit_status()
	_emit_pressure()

func _on_rift_closed(_rift_id: int, closed: int, total: int) -> void:
	rift_progress_changed.emit(closed, total)
	_emit_status()
	if closed >= total:
		return
	var lines: Array = _mission.get("seal_lines", [])
	var text := "RIFT %d OF %d SEALED" % [closed, total]
	if closed - 1 < lines.size():
		text = String(lines[closed - 1])
	_show_message(text, Color(0.3, 1.0, 0.8), 1.5)

func _on_all_rifts_closed() -> void:
	_finish_round(&"victory")

func _on_life_force_depleted() -> void:
	_finish_round(&"defeat")

func _finish_round(outcome: StringName) -> void:
	if _finished:
		return
	_finished = true
	_countdown_active = false
	_paused = false
	_round_active = false
	_director.stop_spawning()
	_life_force.set_process(false)
	if outcome != &"victory":
		_director.cleanup_round()
	for phantom in get_tree().get_nodes_in_group("phantom"):
		if is_instance_valid(phantom) and phantom.has_method("force_cleanup"):
			phantom.force_cleanup()
	# Results presentation belongs exclusively to GameFlowController/VRMenuPresenter.
	if is_instance_valid(_message):
		_message.queue_free()
	_message = null
	round_finished.emit(outcome, score)

func _emit_time_if_changed() -> void:
	var displayed_second := ceili(seconds_remaining)
	if displayed_second == _last_emitted_second:
		return
	_last_emitted_second = displayed_second
	time_changed.emit(seconds_remaining)

func get_debrief(outcome: StringName) -> String:
	match outcome:
		&"victory":
			return String(_mission.get("victory_line", "All rifts sealed."))
		&"defeat":
			return String(_mission.get("defeat_line", "Life force collapsed before the seal."))
		_:
			return String(_mission.get("timeout_line", "The window closed with rifts still open."))

func _emit_status() -> void:
	mission_status_changed.emit(_status_text())

func _emit_pressure() -> void:
	if _director == null:
		return
	var total := maxi(_director.total_rifts, 1)
	var index := maxi(_director.spawned_rifts - 1, 0)
	var ratio := 0.0 if total <= 1 else float(index) / float(total - 1)
	pressure_changed.emit(ratio)

func _status_text() -> String:
	var total := _director.total_rifts if _director else 3
	var closed := _director.closed_rifts if _director else 0
	var codename := String(_mission.get("codename", "RIFTS"))
	if closed >= total and total > 0:
		return "%s  SEALED" % codename
	var current := mini(closed + 1, total)
	var labels: Array = _mission.get("pressure_labels", [])
	var pressure := ""
	if closed < labels.size():
		pressure = "  •  %s" % String(labels[closed])
	if _mission.is_empty():
		return "RIFTS %d/%d" % [closed, total]
	return "%s  %d/%d%s" % [codename, current, total, pressure]

func _reset_combo() -> void:
	if sweet_streak == 0 and is_equal_approx(multiplier, 1.0):
		return
	sweet_streak = 0
	multiplier = 1.0
	_combo_remaining = 0.0
	combo_changed.emit(sweet_streak, multiplier)

func _show_message(text: String, color: Color, lifetime: float) -> void:
	if _message and is_instance_valid(_message):
		_message.queue_free()
	_message = Label3D.new()
	_message.text = text
	_message.font_size = 64
	_message.pixel_size = 0.0035
	_message.modulate = color
	_message.outline_size = 14
	_message.outline_modulate = Color(0.01, 0.02, 0.05, 0.95)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_message.no_depth_test = true
	add_child(_message)
	var camera := _player.get_node_or_null("XRCamera3D") as Node3D if _player else null
	var anchor := camera if camera else _player
	if anchor:
		var forward := -anchor.global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD
		_message.global_position = anchor.global_position + forward * 2.2
		_message.global_position.y = maxf(anchor.global_position.y, 1.45)
	if lifetime > 0.0:
		var timer := get_tree().create_timer(lifetime)
		timer.timeout.connect(_clear_message.bind(_message))

func _clear_message(label: Label3D) -> void:
	if is_instance_valid(label):
		label.queue_free()

