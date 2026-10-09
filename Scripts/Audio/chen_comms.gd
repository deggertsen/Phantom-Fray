extends Node
class_name ChenComms

## Dr. Chen on comms: short spoken callouts at the moments that matter, one at a time.
##
## Every line, its priority, cooldown and delivery note lives in
## Assets/Audio/VO/chen/chen_lines.json. Each line plays from <event>_<n>.ogg beside it, so a
## new recording replaces a placeholder by name. A missing file is skipped and only captioned.
##
## Pacing, as chen_lines.json sets it. Chen never cuts herself off; only the boss turn
## cuts her off (cut_off), because the script asks for it.
##   cooldown  seconds of silence a moment needs after her previous line (any line) finishes
##             before it may start.
##   priority  decides which waiting line gets the next slot. 3 skips the cooldown and plays
##             the moment she finishes.
##   max_wait  a line that cannot start within this many seconds of the moment that triggered
##             it is dropped, because the moment has passed. Priority 3 is never dropped.

signal line_started(speaker: String, text: String, seconds: float)
## She was cut off mid-line (cut_off). The caption should go too.
signal line_cut

const FOLDER := "res://Assets/Audio/VO/chen/"
const SCRIPT := preload("res://Assets/Audio/VO/chen/chen_lines.json")
const DEFAULT_MAX_WAIT := 3.0
const MAX_QUEUE := 3
## Rifts this close to where the player is looking are "dead ahead"; wider ones get a clock bearing.
const IN_VIEW_DEGREES := 50.0
const LIFE_ORDER := {&"healthy": 0, &"caution": 1, &"danger": 2, &"critical": 3, &"depleted": 4}

var _speaker: String = "CHEN"
var _events: Dictionary = {}
var _streams: Dictionary = {}
var _player: AudioStreamPlayer
var _queue: Array[Dictionary] = []
var _playing_event: String = ""
var _clock: float = 0.0
## When her last line finished, and when the one she is saying now will.
var _ended_at: float = -INF
var _speaking_until: float = -INF
var _max_wait: float = DEFAULT_MAX_WAIT
var _last_take: Dictionary = {}
## Counts finished lines, so a caption timer from a line that was cut off cannot end the next one.
var _line_serial: int = 0

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
	_max_wait = float(data.get("pacing", {}).get("max_wait", DEFAULT_MAX_WAIT))
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
	for queued in _queue:
		if queued["event"] == event:
			return
	_queue.append({
		"event": event,
		"priority": int(info.get("priority", 1)),
		"cooldown": float(info.get("cooldown", 0)),
		"at": _clock,
	})
	_queue.sort_custom(_goes_first)
	if _queue.size() > MAX_QUEUE:
		_queue.resize(MAX_QUEUE)

func _process(delta: float) -> void:
	_clock += delta
	_watch_round(delta)
	_queue = _queue.filter(_can_still_start)
	# Speaking until her finished signal lands; the player reports not-playing a frame earlier.
	if _playing_event != "" or _queue.is_empty():
		return
	# The most important waiting line holds the next slot until it can play or is dropped.
	var next: Dictionary = _queue[0]
	if _clock >= _earliest_start(next):
		_queue.pop_front()
		_play(next["event"])

## Most important first; among equals, whatever has waited longest.
func _goes_first(a: Dictionary, b: Dictionary) -> bool:
	return a["priority"] > b["priority"] or (a["priority"] == b["priority"] and a["at"] < b["at"])

## Once she is free, plus the line's cooldown. Priority 3 goes the moment she is free.
func _earliest_start(entry: Dictionary) -> float:
	var free_at := _speaking_until if _playing_event != "" else _ended_at
	if entry["priority"] < 3:
		free_at += float(entry["cooldown"])
	return maxf(free_at, _clock)

## Dropped as soon as it can no longer start within max_wait of its trigger.
func _can_still_start(entry: Dictionary) -> bool:
	return entry["priority"] >= 3 or _earliest_start(entry) - float(entry["at"]) <= _max_wait

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
	if event.begins_with("first_"):
		_introduced[event.trim_prefix("first_")] = true
	# One line per callout in the log, so a headset session shows exactly how chatty she was.
	print("CHEN %.1fs %s_%d" % [_clock, event, take + 1])
	var stream: AudioStream = _streams.get("%s_%d" % [event, take + 1])
	var seconds := 2.2
	if stream:
		_player.stream = stream
		_player.play()
		seconds = stream.get_length()
	else:
		# No recording yet: caption it and hold the line's time as if it were spoken.
		get_tree().create_timer(seconds).timeout.connect(_on_caption_finished.bind(_line_serial))
	_speaking_until = _clock + seconds
	line_started.emit(_speaker, String(lines[take]), seconds)

func _on_line_finished() -> void:
	_ended_at = _clock
	_playing_event = ""
	_line_serial += 1

## A captioned line's time ran out, unless she was cut off and has started another since.
func _on_caption_finished(serial: int) -> void:
	if serial == _line_serial and _playing_event != "":
		_on_line_finished()

## Stops her mid-word and forgets what was waiting. Only the boss's turn does this: the one
## moment the script wants her cut off.
func cut_off() -> void:
	_queue.clear()
	if _playing_event == "":
		return
	_player.stop()
	_on_line_finished()
	line_cut.emit()

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
	# A round that just went live with its clock near zero is a new mission, not a resume.
	if active and not _was_active and _round.elapsed_seconds < 1.0:
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
