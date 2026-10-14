extends Node
class_name TutorialDirector

## Dr. Chen's training chamber: a scripted walk through everything an operator meets in a
## fight, in a simulation where every rift and phantom is a hologram. At the moment a phantom
## would be punched, Chen pauses its hologram (Phantom.hold_in_reach) so she can say what
## matters, and it waits until the operator does the right thing.
##
## The beats run on the real round, rift, life force, and comms systems, so training teaches
## the real rules. The plan, and why it is built this way: development/Tutorial_Plan.md.
## Chen's lines are the tutorial_ events in Assets/Audio/VO/chen/chen_lines.json.
##
## Every wait polls once a frame through _frame(), which holds while paused and turns false
## once the run is stopped, so End Training can stop a beat anywhere without leaving it running.

signal beat_started(beat: StringName)
## Chen signed off. Training is complete.
signal finished
## A phantom's hologram was just paused for this beat. The play capture waits on it.
signal phantom_held(phantom: Node3D)
signal _ticked

const BEATS: Array[StringName] = [
	&"intro", &"play_space", &"rift", &"yellow", &"blue", &"chain", &"green", &"pink",
	&"possession", &"rift_health", &"power", &"live_wave", &"signoff",
]
## How close a paused phantom stops to the eyes: in punching reach, the lure within a jab.
const HOLD_ANGLER := 0.95
const HOLD_CARAPACE := 0.9
## Seconds with nothing useful happening before Chen repeats herself, and how often she will.
const NUDGE_SECONDS := 8.0
const MAX_NUDGES := 2
## Silence between two of her lines.
const BREATH := 0.25
## The head this far from a paused pink's charge line is out of its lane.
const LANE_CLEARANCE := 0.5
## Both grips held this long in the play-space beat says "ready".
const READY_HOLD := 0.5
## The live wave: the rift starts it with at most this much health, and once it is down to
## LAST_CALL_HEALTH it stops feeding, makes sure two phantoms are out, and drops to
## LAST_CALL_TRIM so the next resolve seals it with the other still coming.
const WAVE_HEALTH_CAP := 100
const LAST_CALL_HEALTH := 25
const LAST_CALL_TRIM := 9
## The lure spots ResonancePhantom.place_sweet_spot takes.
const LURE_HOOK := 0
const LURE_JAB := 2
const CARD_COLOR := Color(0.55, 0.92, 1.0)
const TAG_COLOR := Color(0.55, 0.92, 1.0)

## Validation: Chen's lines are recorded but not waited on, pauses are skipped, and phantoms
## start 2.5 m out instead of at the rift.
var fast: bool = false
var beat: StringName = &""
## Every tutorial line asked for, in order.
var spoken: Array[String] = []

var _running: bool = false
var _paused: bool = false
var _run_id: int = 0
var _delta: float = 0.0
var _round: RoundController
var _rifts: RiftDirector
var _life: LifeForceManager
var _chen: ChenComms
var _player: Node3D
var _camera: Node3D
var _hud: Node
var _arena: Node
var _chamber: TrainingChamber
var _rift: RiftManager
var _card: Label3D
var _tags: Array[Node3D] = []
var _readouts: bool = false
var _confirm_pressed: bool = false

## What happened to the phantom in play, from its own signals.
var _current: Phantom
var _result: Dictionary = {}
var _contact: bool = false
var _rejections: int = 0
var _guards: int = 0
## How many of those Chen has already answered. Anything past these, she answers next.
var _answered_rejections: int = 0
var _answered_guards: int = 0
## From the rift director and round, for the chain and the live wave.
var _sealed: bool = false
var _straggler_at_seal: bool = false
var _won: bool = false

func _ready() -> void:
	add_to_group("TutorialDirector")
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_round = get_tree().get_first_node_in_group("RoundController") as RoundController
	_rifts = get_tree().get_first_node_in_group("RiftSpawnManager") as RiftDirector
	_life = get_tree().get_first_node_in_group("LifeForceManager") as LifeForceManager
	_chen = get_tree().get_first_node_in_group("ChenComms") as ChenComms
	_player = get_tree().get_first_node_in_group("Player") as Node3D
	_camera = _player.get_node_or_null("XRCamera3D") as Node3D if _player else null
	_hud = get_tree().get_first_node_in_group("RoundHUD")
	_arena = get_tree().get_first_node_in_group("ArenaPresentation")
	_chamber = TrainingChamber.new()
	_chamber.name = "TrainingChamber"
	add_child(_chamber)
	if _rifts:
		_rifts.phantom_resolved.connect(_on_any_resolved)
		_rifts.rift_closed.connect(_on_rift_closed)
	if _round:
		_round.round_finished.connect(_on_round_finished)

## The training round's mission. Never in MissionCatalog: no unlocks, scores, or times.
static func training_mission() -> Dictionary:
	return {
		"id": "training",
		"codename": "TRAINING",
		"title": "TRAINING CHAMBER 07",
		"tutorial": true,
		"countdown": 0,
		"rift_ahead": true,
		"life_floor": 20.0,
		"objective": "SEAL THE TRAINING RIFT",
		"start_line": "TRAINING CHAMBER 07",
		"pressure_labels": ["SIMULATION"],
		"open_barks": [""],
		"seal_lines": [],
		"mop_up_line": "CLEAR THE LAST ONE",
		# Health high enough that the taught beats never seal it; the live wave trims it.
		"rifts": [{
			"health": 400,
			"interval": 2.8,
			"max_live": 2,
			"speed_scale": 0.75,
			"telegraph_scale": 1.35,
			"pool": ["yellow", "blue", "green", "pink"],
			"scale": 1.0,
			"feed": false,
			"hologram": true,
		}],
	}

func is_running() -> bool:
	return _running

func current_phantom() -> Phantom:
	return _current if is_instance_valid(_current) else null

## From the top, exactly as a new operator gets it.
func start() -> void:
	stop()
	_running = true
	_paused = false
	_run_id += 1
	spoken.clear()
	_chamber.set_active(true)
	if _arena and _arena.has_method("set_training"):
		_arena.set_training(true)
	if _chen:
		_chen.lock_prefix = "tutorial_"
	_run(_run_id)

## Ends the run wherever it is. The caller abandons the round.
func stop() -> void:
	if _running:
		_run_id += 1
	_running = false
	_paused = false
	beat = &""
	_readouts = false
	_current = null
	_rift = null
	_clear_card()
	_clear_tags()
	_highlight(&"")
	if _chamber:
		_chamber.set_active(false)
	if _arena and _arena.has_method("set_training"):
		_arena.set_training(false)
	if _chen and _chen.lock_prefix == "tutorial_":
		_chen.set_paused(false)
		_chen.cut_off()
	if _chen:
		_chen.lock_prefix = ""

## The pause menu holds the run, Chen included, where it is.
func set_paused(paused: bool) -> void:
	_paused = paused
	if _chen and _running:
		_chen.set_paused(paused)

## Desktop debug builds: Enter stands in for squeezing both grips.
func confirm() -> void:
	_confirm_pressed = true

func _process(delta: float) -> void:
	if not _running or _paused:
		return
	_delta = delta
	_ticked.emit()

func _run(id: int) -> void:
	for next in BEATS:
		if not _alive(id):
			return
		beat = next
		beat_started.emit(next)
		var ok := false
		match next:
			&"intro":
				ok = await _beat_intro()
			&"play_space":
				ok = await _beat_play_space()
			&"rift":
				ok = await _beat_rift()
			&"yellow":
				ok = await _beat_angler("yellow", LURE_JAB, "LEFT HAND", "LEFT HAND  •  GRIP, THEN PUNCH THROUGH THE LURE",
					["tutorial_paused", "tutorial_yellow_left", "tutorial_grip_punch", "tutorial_lure", "tutorial_lure_crit"])
			&"blue":
				ok = await _beat_angler("blue", LURE_HOOK, "RIGHT HAND", "RIGHT HAND  •  HOOK THE LURE",
					["tutorial_blue_right", "tutorial_hook"])
			&"chain":
				ok = await _beat_chain()
			&"green":
				ok = await _beat_green()
			&"pink":
				ok = await _beat_pink()
			&"possession":
				ok = await _beat_possession()
			&"rift_health":
				ok = await _beat_rift_health()
			&"power":
				ok = await _beat_power()
			&"live_wave":
				ok = await _beat_live_wave()
			&"signoff":
				ok = await _beat_signoff()
		_clear_card()
		_clear_tags()
		if not ok or not _alive(id):
			return
	_running = false
	beat = &""
	if _chen:
		_chen.lock_prefix = ""
	var settings := get_node_or_null("/root/GameSettings")
	if settings:
		settings.tutorial_completed = true
		settings.save_settings()
	finished.emit()

# --- Beats ---------------------------------------------------------------------

func _beat_intro() -> bool:
	_show_card("DR. ELARA CHEN  //  RSF SCIENCE LEAD")
	return await _say_all(["tutorial_hello", "tutorial_gauntlets", "tutorial_life_force", "tutorial_up_close", "tutorial_chamber", "tutorial_pause_power"])

func _beat_play_space() -> bool:
	_show_card("STAND IN THE RING  •  HOLD META TO RECENTER\nSQUEEZE BOTH GRIPS WHEN READY")
	if not await _say_all(["tutorial_ring", "tutorial_recenter", "tutorial_grips"]):
		return false
	_confirm_pressed = false
	var held_for := [0.0]
	var ready := func() -> bool:
		if fast or _confirm_pressed:
			return true
		held_for[0] = held_for[0] + _delta if _both_grips() else 0.0
		return held_for[0] >= READY_HOLD
	var nudges := 0
	while true:
		var outcome := await _until(ready, NUDGE_SECONDS)
		if outcome < 0:
			return false
		if outcome > 0:
			return true
		if nudges < MAX_NUDGES:
			nudges += 1
			if not await _say("tutorial_grips"):
				return false
	return false

func _beat_rift() -> bool:
	_won = false
	_sealed = false
	_round.begin_round(training_mission())
	if await _until(func() -> bool: return not _rifts.rift_instances.is_empty()) < 0:
		return false
	_rift = _rifts.rift_instances[0] as RiftManager
	return await _say("tutorial_rift_open")

func _beat_angler(variant: String, lure: int, hand_tag: String, card: String, lines: Array) -> bool:
	var phantom := await _send_held(variant, lure, HOLD_ANGLER)
	if phantom == null:
		return false
	_tag(phantom, hand_tag)
	_tag_lure(phantom)
	_show_card(card)
	for line in lines:
		# A punch that lands while she is still explaining ends the explaining.
		if not _result.is_empty():
			break
		if not await _say(line):
			return false
	if not await _await_strike("tutorial_wrong_hand", "tutorial_strike_nudge"):
		return false
	return await _say("tutorial_crit_landed" if _result.get("sweet_spot", false) else "tutorial_plain_landed")

## Live: yellow, blue, yellow, close enough together that the real chain carries between them.
## Three in a row on the round's own chain moves on; three broken waves move on anyway.
func _beat_chain() -> bool:
	_highlight(&"chain")
	_show_card("THREE CLEAN HITS IN A ROW")
	if not await _say_all(["tutorial_chain", "tutorial_chain_live"]):
		return false
	var failed_waves := 0
	while true:
		var wave: Array = []
		for variant in ["yellow", "blue", "yellow"]:
			var phantom := _send(variant)
			if phantom:
				wave.append(phantom)
			if not await _wait(1.4):
				return false
		var outcome := await _until(func() -> bool: return _round.sweet_streak >= 3 or wave.all(_gone))
		if outcome < 0:
			return false
		if _round.sweet_streak >= 3:
			return await _say("tutorial_chain_done")
		failed_waves += 1
		if failed_waves >= 3:
			return await _say("tutorial_chain_enough")
		if not await _say("tutorial_chain_broke"):
			return false
	return false

func _beat_green() -> bool:
	var phantom := await _send_held("green", -1, HOLD_CARAPACE)
	if phantom == null:
		return false
	_tag(phantom, "BOTH HANDS")
	_show_card("BOTH FISTS AT ONCE")
	if not await _say_all(["tutorial_green", "tutorial_green_both"]):
		return false
	var nudges := 0
	while _result.is_empty():
		var outcome := await _until(func() -> bool: return not _result.is_empty() or _guards > _answered_guards or _rejections > _answered_rejections, NUDGE_SECONDS)
		if outcome < 0:
			return false
		if not _result.is_empty():
			break
		var caught := _guards > _answered_guards
		_answered_guards = _guards
		_answered_rejections = _rejections
		if caught:
			# One hand caught it. Give the other hand its window before saying anything.
			if await _until(func() -> bool: return not _result.is_empty(), 0.7) < 0:
				return false
			if not _result.is_empty():
				break
		elif outcome == 0:
			if nudges >= MAX_NUDGES:
				continue
			nudges += 1
		if not await _say("tutorial_green_one"):
			return false
	return await _say("tutorial_green_done")

func _beat_pink() -> bool:
	var phantom := await _send_pink()
	if phantom == null:
		return false
	_tag(phantom, "CAN'T BE PUNCHED")
	_show_card("STEP OUT OF THE LANE, OR DUCK")
	if not await _say_all(["tutorial_pink", "tutorial_pink_lane", "tutorial_pink_move"]):
		return false
	var pink := phantom
	var nudges := 0
	while true:
		var outcome := await _until(func() -> bool: return _out_of_lane(pink) or _rejections > _answered_rejections, NUDGE_SECONDS)
		if outcome < 0:
			return false
		if _out_of_lane(pink):
			break
		if _rejections > _answered_rejections:
			_answered_rejections = _rejections
			if not await _say("tutorial_pink_punch"):
				return false
		elif nudges < MAX_NUDGES:
			nudges += 1
			if not await _say("tutorial_pink_move"):
				return false
	_clear_tags()
	phantom.release_hold()
	if await _until(func() -> bool: return not _result.is_empty() or _contact or _gone(phantom)) < 0:
		return false
	if _result.get("resolution_kind", &"") == &"dodge":
		return await _say("tutorial_pink_done")
	return true

## One gets through on purpose, so possession, the frost, and recovery are seen once.
func _beat_possession() -> bool:
	_show_card("HANDS DOWN  •  LET IT IN")
	for attempt in 2:
		var phantom := await _send_held("yellow", LURE_JAB, HOLD_ANGLER)
		if phantom == null:
			return false
		var lines := ["tutorial_let_in", "tutorial_hands_down"] if attempt == 0 else ["tutorial_let_in_again"]
		for line in lines:
			if not _result.is_empty():
				break
			if not await _say(line):
				return false
		if _result.is_empty():
			phantom.release_hold()
			if await _until(func() -> bool: return not _result.is_empty() or _contact or _gone(phantom)) < 0:
				return false
		if _contact:
			return await _explain_possession()
	# Struck twice. Show the drain anyway: the bar, the frost, and the heartbeat all follow it.
	if not await _say("tutorial_watch_wrist"):
		return false
	if _life:
		_life.apply_damage(_life.drain_on_basic_hit)
	return await _explain_possession()

func _explain_possession() -> bool:
	_highlight(&"life")
	var ok := await _say_all(["tutorial_possessed", "tutorial_life_wrist", "tutorial_recover", "tutorial_failsafe"])
	_highlight(&"")
	return ok

func _beat_rift_health() -> bool:
	_highlight(&"rifts")
	_show_card("EVERY HIT DRAINS THE RIFT")
	var ok := await _say_all(["tutorial_rift_damage", "tutorial_rift_wrist", "tutorial_seal", "tutorial_stragglers"])
	_highlight(&"")
	return ok

## Tap one, then hit one hard, and read the difference off the rift. No lures on these two,
## so the numbers show power alone.
func _beat_power() -> bool:
	_readouts = true
	if not await _say("tutorial_power_intro"):
		return false
	var soft := 0
	for attempt in 3:
		var phantom := await _send_held("yellow", LURE_JAB, HOLD_ANGLER, false)
		if phantom == null:
			return false
		_show_card("TAP IT LIGHTLY")
		if not await _say("tutorial_power_soft" if attempt == 0 else "tutorial_power_lighter"):
			return false
		if not await _await_strike("tutorial_wrong_hand", "tutorial_power_soft"):
			return false
		soft = int(_result.get("rift_damage", 0))
		if float(_result.get("power", 0.0)) < 0.5:
			break
	var lesson_seen := false
	for attempt in 3:
		var phantom := await _send_held("yellow", LURE_JAB, HOLD_ANGLER, false)
		if phantom == null:
			return false
		_show_card("NOW HIT IT HARD")
		if not await _say("tutorial_power_hard" if attempt == 0 else "tutorial_power_again"):
			return false
		if not await _await_strike("tutorial_wrong_hand", "tutorial_power_hard"):
			return false
		if int(_result.get("rift_damage", 0)) > soft:
			lesson_seen = true
			break
	if not lesson_seen:
		push_warning("Training: the hard hit never beat the tap; moving on")
	return await _say_all(["tutorial_power_seen", "tutorial_power_lure"])

func _beat_live_wave() -> bool:
	_readouts = true
	_show_card("SEAL THE RIFT")
	if not await _say("tutorial_live"):
		return false
	_clear_card()
	if _rift == null or not is_instance_valid(_rift):
		return false
	_rift.set_health(mini(_rift.rift_health, WAVE_HEALTH_CAP))
	# Her ordinary callouts come back for the live fight. She has already introduced every color.
	if _chen:
		_chen.mark_introduced(["yellow", "blue", "green", "pink"])
		_chen.lock_prefix = ""
	_rift.feed_enabled = true
	_rift.start_spawning(true)
	var last_called := false
	while not _sealed:
		if not await _frame():
			return false
		if fast and not last_called:
			_rift.set_health(LAST_CALL_HEALTH)
		if not last_called and is_instance_valid(_rift) and _rift.rift_health <= LAST_CALL_HEALTH:
			last_called = true
			_last_call()
			if _chen:
				_chen.lock_prefix = "tutorial_"
			if not await _say("tutorial_last_one"):
				return false
	if _chen:
		_chen.lock_prefix = "tutorial_"
	# With one still out, the round's own mop-up banner says it; the card would only repeat it.
	if _straggler_at_seal:
		_clear_card()
	else:
		_show_card("SEALED")
	if not await _say("tutorial_straggler" if _straggler_at_seal else "tutorial_sealed_clean"):
		return false
	return await _until(func() -> bool: return _won) > 0

## Stop feeding, make sure two are out, and leave the rift one resolve from sealing.
func _last_call() -> void:
	_rift.stop_spawning()
	_rift.feed_enabled = false
	var out := _rift.live_phantoms().size()
	for variant in ["yellow", "blue"]:
		if out >= 2:
			break
		if _send(variant):
			out += 1
	_rift.set_health(mini(_rift.rift_health, LAST_CALL_TRIM))

func _beat_signoff() -> bool:
	_readouts = false
	return await _say_all(["tutorial_signoff_job", "tutorial_signoff_real", "tutorial_signoff_comms"])

# --- Phantoms ------------------------------------------------------------------

## One phantom of this variant out of the training rift, watched as the one in play.
func _send(variant: String, lure: int = -1, lure_visible: bool = true) -> Phantom:
	if _rift == null or not is_instance_valid(_rift):
		return null
	var phantom := _rift.spawn_variant(variant) as Phantom
	if phantom == null:
		return null
	_current = phantom
	_result = {}
	_contact = false
	_rejections = 0
	_guards = 0
	_answered_rejections = 0
	_answered_guards = 0
	phantom.resolved.connect(_on_current_resolved.bind(phantom))
	phantom.player_contact.connect(_on_current_contact.bind(phantom))
	phantom.feedback_requested.connect(_on_current_feedback.bind(phantom))
	var angler := phantom as ResonancePhantom
	if angler:
		if lure >= 0:
			angler.place_sweet_spot(lure)
		if not lure_visible:
			# The power beat: no crits, so the numbers show power alone.
			angler.sweet_spot_radius = 0.0
			angler.sweet_spot_visual.visible = false
	if fast and _camera:
		# A pink closes during its telegraph, so it starts far enough out to lock its lane first.
		phantom.global_position = _camera.global_position + _flat_forward() * (6.0 if variant == "pink" else 2.5)
	return phantom

## Sends one and waits for its hologram to pause in reach. A phantom that stalls out on the
## way in is replaced.
func _send_held(variant: String, lure: int, distance: float, lure_visible: bool = true) -> Phantom:
	for _try in 3:
		var phantom := _send(variant, lure, lure_visible)
		if phantom == null:
			return null
		phantom.hold_in_reach(distance)
		var outcome := await _until(func() -> bool: return _gone(phantom) or phantom.is_held() or not _result.is_empty())
		if outcome < 0:
			return null
		if not _result.is_empty() or (not _gone(phantom) and phantom.is_held()):
			phantom_held.emit(phantom)
			return phantom
	push_warning("Training: no %s reached the operator" % variant)
	return null

func _send_pink() -> SpearfinPhantom:
	for _try in 3:
		var phantom := _send("pink") as SpearfinPhantom
		if phantom == null:
			return null
		phantom.hold_at_lane_lock()
		var outcome := await _until(func() -> bool: return _gone(phantom) or phantom.is_held())
		if outcome < 0:
			return null
		if not _gone(phantom) and phantom.is_held():
			phantom_held.emit(phantom)
			return phantom
	return null

## Waits for a valid strike on the phantom in play. A rejected one gets `wrong_line`; doing
## nothing gets `nudge_line`, at most MAX_NUDGES times.
func _await_strike(wrong_line: String, nudge_line: String) -> bool:
	var nudges := 0
	while _result.is_empty():
		var outcome := await _until(func() -> bool: return not _result.is_empty() or _rejections > _answered_rejections, NUDGE_SECONDS)
		if outcome < 0:
			return false
		if not _result.is_empty():
			break
		if _rejections > _answered_rejections:
			_answered_rejections = _rejections
			if not await _say(wrong_line):
				return false
		elif nudges < MAX_NUDGES:
			nudges += 1
			if not await _say(nudge_line):
				return false
	return true

func _out_of_lane(pink: Variant) -> bool:
	if _camera == null or not is_instance_valid(pink):
		return true
	var line: PackedVector3Array = (pink as SpearfinPhantom).charge_line()
	var closest := Geometry3D.get_closest_point_to_segment(_camera.global_position, line[0], line[1])
	return closest.distance_to(_camera.global_position) > LANE_CLEARANCE

func _on_current_resolved(result: Dictionary, phantom: Phantom) -> void:
	if phantom == _current:
		_result = result
		_clear_tags()

func _on_current_contact(_damage: float, phantom: Phantom) -> void:
	if phantom == _current:
		_contact = true
		_clear_tags()

func _on_current_feedback(kind: StringName, _position: Vector3, _intensity: float, phantom: Phantom) -> void:
	if phantom != _current:
		return
	if kind == &"rejected":
		_rejections += 1
	elif kind == &"guard":
		_guards += 1

func _on_any_resolved(result: Dictionary) -> void:
	if _running and _readouts:
		_readout(result)

func _on_rift_closed(_rift_id: int, _closed: int, _total: int) -> void:
	if not _running:
		return
	_sealed = true
	_straggler_at_seal = _rifts.has_stragglers()

func _on_round_finished(outcome: StringName, _score: int) -> void:
	if _running and outcome == &"victory":
		_won = true

# --- Waiting -------------------------------------------------------------------

func _alive(id: int) -> bool:
	return _running and id == _run_id

## One frame of training time. Holds while paused; false once this run has been stopped.
func _frame() -> bool:
	var id := _run_id
	if not _alive(id):
		return false
	await _ticked
	return _alive(id)

func _wait(seconds: float) -> bool:
	var left := 0.0 if fast else seconds
	while left > 0.0:
		if not await _frame():
			return false
		left -= _delta
	return _running

## 1 when the condition held, 0 when `timeout` seconds ran out first, -1 when the run stopped.
func _until(condition: Callable, timeout: float = -1.0) -> int:
	var left := timeout
	while not condition.call():
		if not await _frame():
			return -1
		if timeout >= 0.0:
			left -= _delta
			if left <= 0.0:
				return 1 if condition.call() else 0
	return 1

## Chen says it; the beat waits until she has finished, then a breath.
func _say(event: String) -> bool:
	spoken.append(event)
	if fast or _chen == null:
		return await _frame()
	_chen.say(event)
	if await _until(func() -> bool: return not _chen.is_busy()) < 0:
		return false
	return await _wait(BREATH)

func _say_all(events: Array) -> bool:
	for event in events:
		if not await _say(event):
			return false
	return true

# --- Presentation --------------------------------------------------------------

func _flat_forward() -> Vector3:
	if _camera == null:
		return Vector3.FORWARD
	var forward := -_camera.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD

## The one thing to do, floating low in front of the operator.
func _show_card(text: String) -> void:
	if _card == null:
		_card = Label3D.new()
		_card.name = "TrainingCard"
		_card.font_size = 44
		_card.pixel_size = 0.0022
		_card.modulate = CARD_COLOR
		_card.outline_size = 12
		_card.outline_modulate = Color(0.01, 0.02, 0.05, 0.95)
		_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_card.no_depth_test = true
		_card.render_priority = 3
		add_child(_card)
	_card.text = text
	_card.visible = true
	if _camera:
		_card.global_position = _camera.global_position + _flat_forward() * 2.0 + Vector3.DOWN * 0.72

func _clear_card() -> void:
	if _card:
		_card.visible = false

func _tag(phantom: Node3D, text: String) -> void:
	_add_tag(text, phantom.global_position + Vector3.UP * 0.42, 40)

func _tag_lure(phantom: Node3D) -> void:
	var lure := phantom.get_node_or_null("SweetSpotVisual") as Node3D
	if lure:
		_add_tag("LURE", lure.global_position + Vector3.UP * 0.1, 30)

func _add_tag(text: String, at: Vector3, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	# The same size on screen near or far: a pink pauses several metres out.
	label.fixed_size = true
	label.pixel_size = 0.0013
	label.modulate = TAG_COLOR
	label.outline_size = 10
	label.outline_modulate = Color(0.01, 0.02, 0.05, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 3
	add_child(label)
	label.global_position = at
	_tags.append(label)

func _clear_tags() -> void:
	for tag in _tags:
		if is_instance_valid(tag):
			tag.queue_free()
	_tags.clear()

## How much a resolve took out of the rift, rising off the hit.
func _readout(result: Dictionary) -> void:
	var damage := int(result.get("rift_damage", 0))
	if damage <= 0:
		return
	var label := Label3D.new()
	label.text = "RIFT −%d" % damage
	label.font_size = 48
	label.pixel_size = 0.002
	label.modulate = Color(1.0, 0.85, 0.35) if result.get("sweet_spot", false) else Color(0.85, 0.75, 1.0)
	label.outline_size = 12
	label.outline_modulate = Color(0.02, 0.0, 0.06, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 3
	add_child(label)
	var at: Vector3 = result.get("world_position", Vector3.ZERO)
	label.global_position = at + Vector3.UP * 0.3
	var tween := label.create_tween()
	tween.tween_property(label, "global_position", label.global_position + Vector3.UP * 0.35, 1.3)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.3).set_delay(0.5)
	tween.tween_callback(label.queue_free)

func _highlight(section: StringName) -> void:
	if _hud and _hud.has_method("set_highlight"):
		_hud.set_highlight(section)

func _both_grips() -> bool:
	if _player == null:
		return false
	for path in [NodePath("LeftHandController"), NodePath("RightHandController")]:
		var controller := _player.get_node_or_null(path) as XRController3D
		if controller == null or not controller.is_button_pressed("grip_click"):
			return false
	return true

## Struck, possessed, stalled out, or freed: no longer coming.
func _gone(phantom: Variant) -> bool:
	return not is_instance_valid(phantom) or not (phantom as Phantom).shows_approach_cue()
