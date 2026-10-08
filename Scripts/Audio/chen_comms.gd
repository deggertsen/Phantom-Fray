extends Node
class_name ChenComms

## Dr. Chen on comms: short spoken callouts at the moments that matter, one at a time.
##
## Every line, its priority, cooldown and delivery note lives in
## Assets/Audio/VO/chen/chen_lines.json. Each line plays from <event>_<n>.ogg beside it, so a
## new recording replaces a placeholder by name. A missing file is skipped and only captioned.
##
## Priorities: 3 interrupts anything lower (critical life, mission end), 2 navigation and
## danger, 1 coaching and progress, 0 flavor. Lines queue behind the one playing; a queued
## line whose moment has passed is dropped rather than said late.

signal line_started(speaker: String, text: String, seconds: float)

const FOLDER := "res://Assets/Audio/VO/chen/"
const SCRIPT := preload("res://Assets/Audio/VO/chen/chen_lines.json")
const GAP := 0.6
const STALE := 3.5
const MAX_QUEUE := 3
## Rifts this close to where the player is looking are "dead ahead"; wider ones get a clock bearing.
const IN_VIEW_DEGREES := 50.0
const LIFE_ORDER := {&"healthy": 0, &"caution": 1, &"danger": 2, &"critical": 3, &"depleted": 4}

var _speaker: String = "CHEN"
var _events: Dictionary = {}
var _streams: Dictionary = {}
var _player: AudioStreamPlayer
var _queue: Array[Dictionary] = []
var _current_priority: int = -1
var _gap_left: float = 0.0
var _clock: float = 0.0
var _last_said: Dictionary = {}
var _last_take: Dictionary = {}

var _round: RoundController
var _director: Node
var _camera: Node3D
var _was_active: bool = false
var _rifts_this_mission: int = 0
var _weakened: Dictionary = {}
var _last_multiplier: float = 1.0
var _last_seconds: float = INF
var _life_level: int = 0
## Phantom kinds already introduced this session, so each gets one coaching line.
var _introduced: Dictionary = {}
var _scan_left: float = 0.0

func _ready() -> void:
	add_to_group("ChenComms")
	var data: Dictionary = (SCRIPT as JSON).data
	_speaker = String(data.get("speaker", "CHEN"))
	_events = data.get("events", {})
	_load_streams()
	_player = AudioStreamPlayer.new()
	_player.name = "Voice"
	_player.bus = &"Voice"
	_player.finished.connect(_on_line_finished)
	add_child(_player)
	await get_tree().process_frame
	_connect()

## Queue a line for one of the events in chen_lines.json.
func say(event: String) -> void:
	var info: Dictionary = _events.get(event, {})
	if info.is_empty():
		return
	var cooldown := float(info.get("cooldown", 0))
	if cooldown > 0.0 and _clock - float(_last_said.get(event, -INF)) < cooldown:
		return
	for queued in _queue:
		if queued["event"] == event:
			return
	var priority := int(info.get("priority", 1))
	if _player.playing and priority >= 3 and priority > _current_priority:
		_player.stop()
		_queue.clear()
		_gap_left = 0.0
		_current_priority = -1
	_queue.append({"event": event, "priority": priority, "at": _clock})
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["priority"] > b["priority"])
	if _queue.size() > MAX_QUEUE:
		_queue.resize(MAX_QUEUE)

func _process(delta: float) -> void:
	_clock += delta
	_gap_left = maxf(_gap_left - delta, 0.0)
	_watch_round(delta)
	if _player.playing or _gap_left > 0.0:
		return
	while not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		if entry["priority"] < 3 and _clock - float(entry["at"]) > STALE:
			continue
		_play(entry)
		break

func _play(entry: Dictionary) -> void:
	var event: String = entry["event"]
	var lines: Array = _events[event].get("lines", [])
	if lines.is_empty():
		return
	var take := 0
	if lines.size() > 1:
		take = randi() % (lines.size() - 1)
		if take >= int(_last_take.get(event, -1)):
			take += 1
	_last_take[event] = take
	_last_said[event] = _clock
	var stream: AudioStream = _streams.get("%s_%d" % [event, take + 1])
	var seconds := 2.2
	if stream:
		_player.stream = stream
		_player.play()
		_current_priority = int(entry["priority"])
		seconds = stream.get_length()
	else:
		_gap_left = seconds
	line_started.emit(_speaker, String(lines[take]), seconds)

func _on_line_finished() -> void:
	_current_priority = -1
	_gap_left = GAP

## Loaded up front: a few dozen short compressed clips, and no hitch on first use.
func _load_streams() -> void:
	for event in _events:
		var lines: Array = _events[event].get("lines", [])
		for i in lines.size():
			var path := "%s%s_%d.ogg" % [FOLDER, event, i + 1]
			if ResourceLoader.exists(path):
				_streams["%s_%d" % [event, i + 1]] = load(path)

# --- Listening to the game -----------------------------------------------------

func _connect() -> void:
	_round = get_tree().get_first_node_in_group("RoundController") as RoundController
	_director = get_tree().get_first_node_in_group("RiftSpawnManager")
	var player := get_tree().get_first_node_in_group("Player") as Node3D
	_camera = player.get_node_or_null("XRCamera3D") as Node3D if player else null
	if _round:
		_round.combo_changed.connect(_on_combo_changed)
		_round.time_changed.connect(_on_time_changed)
		_round.round_finished.connect(_on_round_finished)
	if _director:
		_director.rift_spawned.connect(_on_rift_spawned)
		_director.rift_closed.connect(_on_rift_closed)
		_director.strike_rejected.connect(_on_strike_rejected)
	var life := get_tree().get_first_node_in_group("LifeForceManager")
	if life:
		life.life_force_state_changed.connect(_on_life_state_changed)
		life.damage_applied.connect(_on_damage_applied)

func _watch_round(delta: float) -> void:
	if _round == null:
		return
	var active := _round.is_round_active()
	# A round that just went live with its whole clock left is a new mission, not a resume.
	if active and not _was_active and _round.seconds_remaining >= _round.round_duration - 1.0:
		_begin_mission()
	_was_active = active
	if not active:
		return
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = 0.5
		for phantom in get_tree().get_nodes_in_group("phantom"):
			var kind := String(phantom.get("variant_id"))
			if kind != "" and not _introduced.has(kind) and _events.has("first_" + kind):
				_introduced[kind] = true
				say("first_" + kind)

func _begin_mission() -> void:
	_queue.clear()
	_rifts_this_mission = 0
	_weakened.clear()
	_last_multiplier = 1.0
	_last_seconds = INF
	_life_level = 0
	say("mission_start")

func _on_rift_spawned(rift_id: int, rift: Node3D) -> void:
	_rifts_this_mission += 1
	if rift and rift.has_signal("health_changed"):
		rift.health_changed.connect(_on_rift_health.bind(rift_id))
	# The first rift opens as the mission starts; the mission line covers it.
	if _rifts_this_mission == 1 or rift == null or _camera == null:
		return
	say(_bearing_event(rift.global_position))

## "rift_ahead" inside the gaze, otherwise the clock position: 3 is right, 6 behind, 9 left.
func _bearing_event(target: Vector3) -> String:
	var forward := -_camera.global_transform.basis.z
	var right := _camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	var to_target := target - _camera.global_position
	to_target.y = 0.0
	var angle := rad_to_deg(atan2(to_target.dot(right.normalized()), to_target.dot(forward.normalized())))
	if absf(angle) <= IN_VIEW_DEGREES:
		return "rift_ahead"
	var hour := wrapi(roundi(angle / 30.0), 0, 12)
	return "rift_oclock_%d" % hour

func _on_rift_health(current: int, maximum: int, rift_id: int) -> void:
	if not _weakened.has(rift_id) and current > 0 and current <= maximum / 2:
		_weakened[rift_id] = true
		say("rift_weakening")

func _on_rift_closed(_rift_id: int, closed: int, total: int) -> void:
	if closed < total:
		say("rift_sealed")

func _on_strike_rejected(reason: StringName) -> void:
	if reason == &"wrong_hand":
		say("wrong_hand")

func _on_combo_changed(_streak: int, multiplier: float) -> void:
	if _round and multiplier >= _round.maximum_multiplier and _last_multiplier < _round.maximum_multiplier:
		say("combo_max")
	elif multiplier >= 2.0 and _last_multiplier < 2.0:
		say("combo_rising")
	_last_multiplier = multiplier

func _on_time_changed(seconds: float) -> void:
	if _round and _round.is_round_active():
		if seconds <= 60.0 and _last_seconds > 60.0 and _round.round_duration > 90.0:
			say("time_60")
		elif seconds <= 30.0 and _last_seconds > 30.0:
			say("time_30")
	_last_seconds = seconds

func _on_life_state_changed(state: StringName) -> void:
	var level: int = LIFE_ORDER.get(state, 0)
	# Only call it out as things get worse; recovering needs no comment.
	if level > _life_level:
		match state:
			&"caution":
				say("life_caution")
			&"danger":
				say("life_danger")
			&"critical":
				say("life_critical")
	_life_level = level

func _on_damage_applied(_amount: float, _current: float) -> void:
	if _life_level < 3:
		say("possessed")

func _on_round_finished(outcome: StringName, _score: int) -> void:
	_queue.clear()
	match outcome:
		&"victory":
			say("victory")
		&"defeat":
			say("defeat")
		_:
			say("timeout")
