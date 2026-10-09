extends Node
class_name ChenComms

## Dr. Chen on comms: short spoken callouts at the moments that matter, one at a time.
##
## Every line, its priority, cooldown and delivery note lives in
## Assets/Audio/VO/chen/chen_lines.json. Each line plays from <event>_<n>.ogg beside it, so a
## new recording replaces a placeholder by name. A missing file is skipped and only captioned.
##
## Priority: 3 is the end of a mission and critical life force, 2 navigation and danger,
## 1 coaching and progress, 0 flavor. Chen never cuts herself off. A waiting line plays once
## she has been quiet long enough for its priority; the most important goes first. A line that
## waits longer than MAX_WAIT is dropped, because its moment has passed. Mission results are
## never dropped. Cooldowns count from when that moment's last line ended.

signal line_started(speaker: String, text: String, seconds: float)

const FOLDER := "res://Assets/Audio/VO/chen/"
const SCRIPT := preload("res://Assets/Audio/VO/chen/chen_lines.json")
## Seconds of silence a line needs after the last one ended, by priority.
const QUIET := {0: 1.0, 1: 0.8, 2: 0.5, 3: 0.3}
const MAX_WAIT := 3.0
const MAX_QUEUE := 3
## Rifts this close to where the player is looking are "dead ahead"; wider ones get a clock bearing.
const IN_VIEW_DEGREES := 50.0
const LIFE_ORDER := {&"healthy": 0, &"caution": 1, &"danger": 2, &"critical": 3, &"depleted": 4}
const RESULTS := ["victory", "victory_flawless", "victory_critical", "victory_record", "defeat"]

var _speaker: String = "CHEN"
var _events: Dictionary = {}
var _streams: Dictionary = {}
var _player: AudioStreamPlayer
var _queue: Array[Dictionary] = []
var _playing_event: String = ""
var _clock: float = 0.0
var _ended_at: float = -INF
var _last_ended: Dictionary = {}
var _last_take: Dictionary = {}

var _round: RoundController
var _director: Node
var _camera: Node3D
var _life: Node
var _was_active: bool = false
var _rifts_this_mission: int = 0
var _weakened: Dictionary = {}
var _last_multiplier: float = 1.0
var _life_level: int = 0
var _took_damage: bool = false
var _mission_id: String = ""
var _best_before: int = 0
## How the last attempt at each mission ended this session, for the retry line.
var _last_outcome: Dictionary = {}
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
	if info.is_empty() or event == _playing_event:
		return
	var cooldown := float(info.get("cooldown", 0))
	if cooldown > 0.0 and _clock - float(_last_ended.get(event, -INF)) < cooldown:
		return
	for queued in _queue:
		if queued["event"] == event:
			return
	_queue.append({"event": event, "priority": int(info.get("priority", 1)), "at": _clock})
	_queue.sort_custom(_goes_first)
	if _queue.size() > MAX_QUEUE:
		_queue.resize(MAX_QUEUE)

func _process(delta: float) -> void:
	_clock += delta
	_watch_round(delta)
	_queue = _queue.filter(_still_relevant)
	if _player.playing or _queue.is_empty():
		return
	var next: Dictionary = _queue[0]
	if _clock - _ended_at >= float(QUIET.get(next["priority"], 1.0)):
		_queue.pop_front()
		_play(next["event"])

## Most important first; among equals, whatever has waited longest.
func _goes_first(a: Dictionary, b: Dictionary) -> bool:
	return a["priority"] > b["priority"] or (a["priority"] == b["priority"] and a["at"] < b["at"])

## A waiting line's moment passes after MAX_WAIT. A mission result always gets said.
func _still_relevant(entry: Dictionary) -> bool:
	return entry["event"] in RESULTS or _clock - float(entry["at"]) <= MAX_WAIT

func _play(event: String) -> void:
	var lines: Array = _events[event].get("lines", [])
	if lines.is_empty():
		return
	var take := 0
	if lines.size() > 1:
		take = randi() % (lines.size() - 1)
		if take >= int(_last_take.get(event, -1)):
			take += 1
	_last_take[event] = take
	_playing_event = event
	var stream: AudioStream = _streams.get("%s_%d" % [event, take + 1])
	var seconds := 2.2
	if stream:
		_player.stream = stream
		_player.play()
		seconds = stream.get_length()
	else:
		# No recording yet: caption it and hold the line's time as if it were spoken.
		get_tree().create_timer(seconds).timeout.connect(_on_line_finished)
	line_started.emit(_speaker, String(lines[take]), seconds)

func _on_line_finished() -> void:
	_ended_at = _clock
	if _playing_event != "":
		_last_ended[_playing_event] = _clock
	_playing_event = ""

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
	_life = get_tree().get_first_node_in_group("LifeForceManager")
	var player := get_tree().get_first_node_in_group("Player") as Node3D
	_camera = player.get_node_or_null("XRCamera3D") as Node3D if player else null
	if _round:
		_round.combo_changed.connect(_on_combo_changed)
		_round.round_finished.connect(_on_round_finished)
	if _director:
		_director.rift_spawned.connect(_on_rift_spawned)
		_director.rift_closed.connect(_on_rift_closed)
		_director.strike_rejected.connect(_on_strike_rejected)
	if _life:
		_life.life_force_state_changed.connect(_on_life_state_changed)
		_life.damage_applied.connect(_on_damage_applied)

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
	_life_level = 0
	_took_damage = false
	_mission_id = String(_round.current_mission().get("id", ""))
	var settings := get_node_or_null("/root/GameSettings")
	var cleared: bool = settings != null and settings.has_cleared_mission(_mission_id)
	_best_before = settings.best_score(_mission_id) if settings else 0
	say(_mission_start_event(cleared))

## The opening line knows the operator's history with this breach.
func _mission_start_event(cleared: bool) -> String:
	if _last_outcome.get(_mission_id, &"") == &"defeat":
		return "mission_start_retry"
	if cleared:
		return "mission_start_replay"
	if not _last_outcome.has(_mission_id):
		return "mission_start_first"
	return "mission_start"

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
	_took_damage = true
	if _life_level < 3:
		say("possessed")

## Victory lines react to how it went: untouched, at critical, a new best, or simply sealed.
## A defeat means the gauntlets' failsafe fired and the recovery team is pulling the operator out.
func _on_round_finished(outcome: StringName, score: int) -> void:
	_queue.clear()
	_last_outcome[_mission_id] = outcome
	match outcome:
		&"victory":
			if _life_level >= 3:
				say("victory_critical")
			elif not _took_damage:
				say("victory_flawless")
			elif _best_before > 0 and score > _best_before:
				say("victory_record")
			else:
				say("victory")
		&"defeat":
			say("defeat")
