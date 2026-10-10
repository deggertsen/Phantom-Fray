extends Node3D
class_name MawBoss

## The Maw as the first boss. Phase one is the ordinary Maw. On a Maw that breaks, the rift's
## health reaching zero plays the turn instead of the seal: the false seal, the silence, the
## phantoms fleeing to circle the rift, the rift tearing wider, a tentacle rising over the
## player, Chen, a harmless shockwave, the boss music. Then phase two: the rift's health bar is
## the boss's anchor. It drains on its own, refills on possessions, and drains faster on work
## (resolves, and pulses into a spent tentacle). At zero the tentacles pull back, the rift
## closes, and the mission is won. Bosses never die; they retreat.
##
## A Maw that does not break may instead end on the tentacle glimpse: as it seals, a tentacle
## grips the rim and is dragged back through.
##
## Lives under the RiftDirector, which hands it each mission in start_round. Nothing here runs
## unless the mission carries a "boss" or "glimpse" key, and only debug missions carry "boss"
## until the war map's difficulties exist (MissionCatalog.debug_missions).
## See development/Exercise_Mechanics_Exploration.md, "The Maw" through "Phantoms in a boss fight".

signal phase_two_started(boss_name: String, rift_id: int)
signal retreated

enum Stage { IDLE, PHASE_ONE, TURN, FIGHT, RETREAT, GLIMPSE, DONE }

const SweepScene := "res://Scenes/Hazards/resonance_sweep.tscn"
const BOSS_LIGHT := Color(0.85, 0.12, 0.3)
## The turn, start to the first second of the fight.
const TURN_SECONDS := 12.0
## The Maw tears this much wider than its phase-one size during the turn.
const TORN_SCALE_GAIN := 1.6
const ESCORT_ORBIT := 0.16
## Anchor a possession feeds back to the boss, and anchor each push-up pulse drains.
const POSSESSION_FEED := 20
const PULSE_DRAIN := 12
const REFILL_SECONDS := 1.5
const SPENT_SECONDS := 20.0
const SPENT_PUSH_UPS := 10
## "Up. It's waking." comes this long before the spent tentacle recoils.
const WAKE_WARNING := 1.5
const RECOIL_SECONDS := 1.5
## Every attack holds this long after a recoil, so the player is up before anything comes.
const STAND_UP_SECONDS := 2.5
const RETREAT_SECONDS := 2.2
const GLIMPSE_ODDS := 0.25
const GLIMPSE_SECONDS := 3.4
## One phase-one Maw in three lets a boss through, after the first (decision 29).
const BREAK_ODDS := 1.0 / 3.0

## The authored pattern. The opener asks for the easiest thing first: a slow sweep with a
## long tell. Then the cycle repeats until the anchor runs out.
const OPENER := [
	{"do": "sweep", "tell": 2.2, "speed": 3.4, "side": 1.0},
	{"do": "rest", "seconds": 4.0},
	{"do": "volley"},
	{"do": "rest", "seconds": 4.0},
]
const CYCLE := [
	{"do": "sweep", "tell": 1.5, "speed": 4.6, "side": -1.0},
	{"do": "rest", "seconds": 3.0},
	{"do": "slam"},
	{"do": "summon"},
	{"do": "rest", "seconds": 3.5},
	{"do": "sweep", "tell": 1.4, "speed": 5.0, "side": 1.0},
	{"do": "rest", "seconds": 3.0},
	{"do": "volley"},
	{"do": "rest", "seconds": 4.0},
]

## Set by a debug key: the next boss Maw breaks whatever the odds say.
static var force_next_break: bool = false
## Set by --maw-breaks on the command line (debug builds): every boss Maw breaks, for headset tests.
static var always_break: bool = false

var stage: Stage = Stage.IDLE
var boss_config: Dictionary = {}
var breaks: bool = false
var glimpse: bool = false
var anchor_maximum: int = 840
var drain_per_second: float = 4.0
## Push-ups on the current spent tentacle.
var push_ups: int = 0

var _director: Node
var _rift: RiftManager
var _clock: float = 0.0
var _fired: Dictionary = {}
var _drain_carry: float = 0.0
## Anchor the refill has handed back so far.
var _refilled: int = 0
var _tentacle: MawTentacle
## Phantoms circling the rift. Untyped: a freed one must not trip a typed assignment.
var _escorts: Array = []
var _steps: Array = []
var _step: Dictionary = {}
var _step_time: float = 0.0
var _step_phase: StringName = &""
var _phase_time: float = 0.0
var _sweep: Node3D
var _slam: MawSlam
var _frame: Dictionary = {}
var _from_pose: Array[Vector3] = []
var _released: int = 0
var _rumble: AudioStreamPlayer3D
## Built when a break is decided, in the countdown, so the turn never waits on them.
var _rumble_stream: AudioStreamWAV
var _roar_stream: AudioStreamWAV
var _stream_task: int = -1
var _shockwave: Node3D
var _turn_mood: float = 0.0
var _phase_one_scale: float = 2.0
var _ducked: bool = false
var _paused: bool = false

func _ready() -> void:
	add_to_group("boss")
	add_to_group("MawBoss")
	top_level = true
	_director = get_parent()
	if _director and _director.has_signal("player_damaged"):
		_director.player_damaged.connect(_on_player_damaged)
		_director.rift_spawned.connect(_on_rift_spawned)
	await get_tree().process_frame
	var push_ups_source := get_tree().get_first_node_in_group("PushUpDetector")
	if push_ups_source and push_ups_source.has_signal("push_up_completed"):
		push_ups_source.push_up_completed.connect(register_push_up)

## The break odds (decision 29): the first Maw at the boss difficulty always breaks, then about
## one in three, and never three in a row without a boss. `roll` is uniform in [0, 1).
static func decide_break(maws_faced: int, maws_without_boss: int, roll: float, odds: float = BREAK_ODDS) -> bool:
	if maws_faced <= 0:
		return true
	if maws_without_boss >= 2:
		return true
	return roll < odds

## The anchor's drain per second, so it runs dry in `seconds` with no hits and no work.
static func drain_rate(maximum: int, seconds: float) -> float:
	return float(maximum) / maxf(seconds, 1.0)

## A new mission is starting. Decides now whether this Maw breaks, as the design asks.
func prepare(mission: Dictionary) -> void:
	cleanup()
	boss_config = mission.get("boss", {})
	breaks = false
	glimpse = false
	var settings := get_node_or_null("/root/GameSettings")
	if not boss_config.is_empty():
		var faced: int = int(settings.get("boss_maws_faced")) if settings else 0
		var dry: int = int(settings.get("maws_without_boss")) if settings else 0
		breaks = force_next_break or always_break or decide_break(faced, dry, randf())
		force_next_break = false
		if settings and settings.has_method("record_maw"):
			settings.record_maw(breaks)
		anchor_maximum = int(boss_config.get("anchor", anchor_maximum))
		drain_per_second = drain_rate(anchor_maximum, float(boss_config.get("anchor_seconds", 210.0)))
		print("MAW BOSS: %s (boss Maws faced %d, %d in a row without a boss)" % ["BREAKS" if breaks else "holds", faced, dry])
		if breaks and _rumble_stream == null and _stream_task < 0:
			# Built off the main thread while phase one plays, so nothing hitches.
			_stream_task = WorkerThreadPool.add_task(_build_streams)
	elif bool(mission.get("glimpse", false)):
		var first_seal: bool = settings == null or not settings.has_cleared_mission(String(mission.get("id", "")))
		glimpse = first_seal or randf() < GLIMPSE_ODDS
	stage = Stage.PHASE_ONE if breaks or glimpse else Stage.IDLE

func _build_streams() -> void:
	var rumble := MawTurnFX.rumble_stream()
	var roar := MawTurnFX.roar_stream()
	_take_streams.call_deferred(rumble, roar)

func _take_streams(rumble: AudioStreamWAV, roar: AudioStreamWAV) -> void:
	if _stream_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_stream_task)
		_stream_task = -1
	_rumble_stream = rumble
	_roar_stream = roar

func _exit_tree() -> void:
	if _stream_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_stream_task)
		_stream_task = -1

## Puts everything back: no tentacle, no duck, no boss light. Safe to call at any time.
func cleanup() -> void:
	stage = Stage.IDLE
	_rift = null
	_clock = 0.0
	_fired.clear()
	_escorts.clear()
	_steps.clear()
	_step = {}
	push_ups = 0
	_paused = false
	set_process(true)
	if is_instance_valid(_tentacle):
		_tentacle.queue_free()
	_tentacle = null
	if is_instance_valid(_rumble):
		_rumble.queue_free()
	_rumble = null
	if is_instance_valid(_shockwave):
		_shockwave.queue_free()
	_shockwave = null
	_sweep = null
	_slam = null
	_restore_audio()
	_set_turn_mood(0.0)
	var music := _music()
	if music and music.has_method("end_boss"):
		music.end_boss()
	var comms := _comms()
	if comms and "scripted" in comms:
		comms.scripted = false

## Pause holds the turn and the fight exactly where they are. RoundController calls this.
func set_round_paused(paused: bool) -> void:
	_paused = paused
	set_process(not paused)
	if is_instance_valid(_tentacle):
		_tentacle.set_process(not paused)
	if is_instance_valid(_rumble):
		_rumble.stream_paused = paused

func is_fighting() -> bool:
	return stage == Stage.FIGHT

## The spent-tentacle window is open: push-ups on it drain the anchor.
func is_spent_window_open() -> bool:
	return stage == Stage.FIGHT and _step.get("do", "") == "slam" and _step_phase in [&"spent", &"waking"]

## One push-up on a spent tentacle. Push-up detection does not exist yet: a future detector in
## the "PushUpDetector" group with a push_up_completed signal is connected in _ready, and debug
## builds map the P key here (GameFlowController).
func register_push_up() -> void:
	if not is_spent_window_open() or push_ups >= SPENT_PUSH_UPS or _rift == null:
		return
	push_ups += 1
	_rift.apply_result({
		"variant_id": &"pulse",
		"valid": true,
		"sweet_spot": false,
		"resolution_kind": &"pulse",
		"base_score": 60,
		"rift_damage": PULSE_DRAIN,
		"hit_quality": 0.0,
		"world_position": _tentacle.tip() if _tentacle else global_position,
		"failure_reason": &"",
		"on_beat": true,
	})
	if _tentacle:
		_tentacle.pulse = 1.0

# --- Wiring ------------------------------------------------------------------------

func _on_rift_spawned(_rift_id: int, rift: Node3D) -> void:
	if stage != Stage.PHASE_ONE or _rift != null or not rift is RiftManager:
		return
	_rift = rift as RiftManager
	_phase_one_scale = _rift.rift_scale()
	if breaks:
		_rift.hold_open = true
		var share := clampf(float(boss_config.get("phase_one_scale", 1.0)), 0.1, 1.0)
		_rift.maximum_health = maxi(int(round(_rift.maximum_health * share)), 1)
		_rift.rift_health = _rift.maximum_health
		_rift.held_at_zero.connect(_on_rift_held)
	elif glimpse:
		_rift.closed.connect(_on_glimpse_seal)

func _on_rift_held() -> void:
	match stage:
		Stage.PHASE_ONE:
			_begin_turn()
		Stage.FIGHT:
			_begin_retreat()

func _on_player_damaged(_amount: float) -> void:
	if stage == Stage.FIGHT and _rift:
		_rift.restore_health(POSSESSION_FEED)

# --- The loop ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if _shockwave and not MawTurnFX.advance_shockwave(_shockwave, delta):
		_shockwave = null
	match stage:
		Stage.TURN:
			_clock += delta
			_tick_turn()
		Stage.FIGHT:
			_clock += delta
			_tick_fight(delta)
		Stage.RETREAT:
			_clock += delta
			_tick_retreat()
		Stage.GLIMPSE:
			_clock += delta
			_tick_glimpse()
		Stage.DONE:
			# The boss light drains out after a retreat.
			if _turn_mood > 0.0:
				_set_turn_mood(maxf(_turn_mood - delta / 3.0, 0.0))

## True once, the first frame the stage clock passes `at`.
func _beat(name: String, at: float) -> bool:
	if _fired.has(name) or _clock < at:
		return false
	_fired[name] = true
	return true

# --- The turn ----------------------------------------------------------------------

func _begin_turn() -> void:
	stage = Stage.TURN
	_clock = 0.0
	_fired.clear()
	_rift.feed_enabled = false
	_rift.set_dissolve_override(0.0)
	_tick_turn()

func _tick_turn() -> void:
	var comms := _comms()
	var music := _music()
	# 1. The false seal (0 s): the portal starts to dissolve, the music resolves, Chen starts her line.
	if _beat("false_seal", 0.0):
		if music and music.has_method("false_seal"):
			music.false_seal()
		if comms:
			comms.cut_off()
			# Nothing but the turn's own lines until the fight starts.
			comms.scripted = true
			comms.say("boss_false_seal")
	# 2. Silence (0.5 s): she cuts off, the music stops dead, everything ducks but a low rumble.
	if _beat("silence", 0.5):
		if comms:
			comms.cut_off()
		if music and music.has_method("cut"):
			music.cut()
		_duck_audio()
		_rumble = MawTurnFX.play_at(self, _rumble_stream if _rumble_stream else MawTurnFX.rumble_stream(), _rift.portal_center(), -2.0)
	# The dissolve runs as a seal does, freezes in the silence, then runs backwards.
	var dissolve := 0.0
	if _clock < 0.5:
		dissolve = _clock * 0.75
	elif _clock < 1.2:
		dissolve = 0.375
	else:
		dissolve = 0.375 * (1.0 - smoothstep(1.2, 3.0, _clock))
	_rift.set_dissolve_override(dissolve)
	# 3. They run (1 s): every phantom still out turns and flees to a slow ring around the Maw.
	if _beat("flee", 1.0):
		_gather_escort(_rift.live_phantoms())
	# 4. It tears (3 to 5 s): wider, the sky crack, the veins to the player's feet, the pylons, the light.
	var tear := smoothstep(3.0, 5.0, _clock)
	_rift.set_rift_scale(_phase_one_scale * lerpf(1.0, TORN_SCALE_GAIN, tear))
	_set_turn_mood(tear)
	# 5. The first tentacle (5 to 8 s): slides out along the floor, stops short, then rises.
	if _beat("tentacle", 5.0):
		_spawn_tentacle()
	if _tentacle and _clock >= 5.0:
		var frame := _player_frame()
		if _clock < 5.5:
			_tentacle.set_path(_blend(_collapsed(frame), _slide_pose(frame, 0.08), smoothstep(5.0, 5.5, _clock)))
		elif _clock < 6.9:
			_tentacle.set_path(_slide_pose(frame, lerpf(0.08, 1.0, smoothstep(5.5, 6.9, _clock))))
		else:
			_tentacle.set_path(_rise_pose(frame, smoothstep(6.9, 8.0, _clock)))
	# 6. Chen (8 to 10 s).
	if _beat("chen", 8.0) and comms:
		comms.say("boss_holding_open")
		comms.say("boss_not_a_phantom")
	# 7. The roar (10 s): low and spatial, and a harmless ring rolls out below eye level.
	if _beat("roar", 10.0):
		MawTurnFX.play_at(self, _roar_stream if _roar_stream else MawTurnFX.roar_stream(), _rift.portal_center(), 4.0)
		_shockwave = MawTurnFX.shockwave(self, _rift.global_position, _reduced_flashes())
	# 8. The fight (12 s).
	if _clock >= TURN_SECONDS:
		_begin_fight()

func _spawn_tentacle() -> void:
	if is_instance_valid(_tentacle):
		_tentacle.queue_free()
	_tentacle = MawTentacle.new()
	_tentacle.name = "MawTentacle"
	add_child(_tentacle)
	_tentacle.set_path(_collapsed(_player_frame()))

func _gather_escort(phantoms: Array[Node3D]) -> void:
	var ring := _escort_ring()
	var count := phantoms.size()
	for i in count:
		var phantom := phantoms[i] as Phantom
		if phantom == null:
			# Anything that is not a phantom (a sweep in flight) just goes out.
			if phantoms[i].has_method("force_cleanup"):
				phantoms[i].force_cleanup()
			continue
		var angle := TAU * float(i) / float(maxi(count, 1)) + randf_range(-0.2, 0.2)
		phantom.enter_escort(ring["center"], ring["right"], ring["radii"], angle, ESCORT_ORBIT)
		if not _escorts.has(phantom):
			_escorts.append(phantom)

## An upright ring around the torn mouth, a little in front of it, never below the knees.
func _escort_ring() -> Dictionary:
	var torn := _phase_one_scale * TORN_SCALE_GAIN
	var half := 2.0 * torn
	var toward := _toward_player_from_rift()
	var right := toward.cross(Vector3.UP).normalized()
	var center := _rift.global_position + Vector3.UP * 2.0 * (torn - 1.0) + toward * 1.2
	var radii := Vector2(half + 1.2, minf(half * 0.85, center.y - 0.9))
	return {"center": center, "right": right, "radii": radii}

# --- The fight ---------------------------------------------------------------------

func _begin_fight() -> void:
	stage = Stage.FIGHT
	_clock = 0.0
	_fired.clear()
	_drain_carry = 0.0
	_refilled = 0
	_restore_audio()
	if is_instance_valid(_rumble):
		_rumble.queue_free()
	_rumble = null
	_rift.set_dissolve_override(0.0)
	_rift.begin_anchor(anchor_maximum)
	var music := _music()
	if music and music.has_method("boss_theme"):
		music.boss_theme()
	var comms := _comms()
	if comms:
		comms.say("boss_get_ready")
		comms.scripted = false
	phase_two_started.emit(String(boss_config.get("name", "THE MAW")), _rift.rift_id)
	_steps = OPENER.duplicate(true)
	_from_pose = _tentacle.path().duplicate() if _tentacle else []
	# The first attack waits for the bar to fill and Chen to finish.
	_steps.push_front({"do": "rest", "seconds": REFILL_SECONDS + 1.5})
	_next_step()

func _tick_fight(delta: float) -> void:
	if _refilled < anchor_maximum:
		# The hex refills as the anchor: the boss is what holds the rift open now.
		var target := int(round(anchor_maximum * minf(_clock / REFILL_SECONDS, 1.0)))
		_rift.restore_health(target - _refilled)
		_refilled = target
	else:
		_drain_carry += drain_per_second * delta
		var drained := int(_drain_carry)
		_drain_carry -= drained
		_rift.drain_health(drained)
		if stage != Stage.FIGHT:
			return
	_prune_escort()
	_step_time += delta
	_phase_time += delta
	if _run_step(delta):
		_next_step()

func _next_step() -> void:
	if _steps.is_empty():
		_steps = CYCLE.duplicate(true)
	_step = _steps.pop_front()
	_step_time = 0.0
	_phase_time = 0.0
	_step_phase = &""
	_from_pose = _tentacle.path().duplicate() if _tentacle else []
	match String(_step.get("do", "")):
		"sweep":
			_start_sweep()
		"slam":
			_start_slam()
		"summon":
			_summon_escort()
		"volley":
			_released = 0
			if not _escorts.is_empty():
				var comms := _comms()
				if comms:
					comms.say("boss_volley")

## Advances the current step. True when it is finished.
func _run_step(_delta: float) -> bool:
	match String(_step.get("do", "")):
		"rest":
			_pose_hover()
			return _step_time >= float(_step.get("seconds", 2.0))
		"sweep":
			return _run_sweep()
		"slam":
			return _run_slam()
		"volley":
			_pose_hover()
			return _run_volley()
	return true

## The idle tentacle hangs over the arena in front of the player, swaying.
func _pose_hover() -> void:
	if _tentacle == null:
		return
	_tentacle.writhe = 0.45
	_tentacle.dim = move_toward(_tentacle.dim, 0.0, 0.02)
	var target := _hover_pose(_player_frame())
	var blend := smoothstep(0.0, 1.2, _step_time)
	_tentacle.set_path(_blend(_from_pose, target, blend) if _from_pose.size() == target.size() else target)

# --- The high sweep: Step 3's resonance sweep, driven from the tentacle ----------------

func _start_sweep() -> void:
	if not ResourceLoader.exists(SweepScene):
		push_warning("MawBoss: %s is missing, so the tentacle cannot sweep" % SweepScene)
		_sweep = null
		return
	var sweep := (load(SweepScene) as PackedScene).instantiate() as Node3D
	var frame := _player_frame()
	var side := float(_step.get("side", 1.0))
	sweep.set("squat_depth", float(boss_config.get("squat_depth", 0.20)))
	sweep.set("telegraph_seconds", float(_step.get("tell", 1.5)))
	sweep.set("blade_speed", float(_step.get("speed", 5.0)))
	# In from one side, across the player. The rails still light the line; the limb is the blade.
	sweep.set("side", side)
	sweep.set("blade_visible", false)
	_rift.add_attacker(sweep, frame["p"] + frame["r"] * side * 6.0)
	_sweep = sweep
	var comms := _comms()
	if comms:
		comms.say("boss_sweep")

func _run_sweep() -> bool:
	if _sweep == null or not is_instance_valid(_sweep):
		_sweep = null
		if _tentacle:
			_pose_hover()
		return _step_time >= 1.2
	if _tentacle == null:
		return not _sweep.call("is_in_flight")
	var frame := _player_frame()
	var blade: Vector3 = _sweep.call("blade_position")
	if float(_sweep.call("telegraph_progress")) < 1.0:
		# Drawn back past where the blade starts, a little above the line, coiling.
		_tentacle.writhe = 0.7
		var p: Vector3 = frame["p"]
		var flat := Vector3(blade.x - p.x, 0.0, blade.z - p.z)
		var drawn := p + flat * 1.2 + Vector3.UP * (blade.y + 0.9)
		var back := _sweep_pose(frame, drawn)
		_tentacle.set_path(_blend(_from_pose, back, smoothstep(0.0, 0.8, _step_time)) if _from_pose.size() == back.size() else back)
		return false
	# Crossing: the limb lies along the line to the rift and runs sideways with the blade.
	# Its underside sits on the blade's line, so a head under the blade is under the limb too.
	_tentacle.writhe = 0.08
	_tentacle.set_path(_sweep_pose(frame, blade + Vector3.UP * 0.22))
	if not _sweep.call("is_in_flight"):
		_sweep = null
		_step_time = 0.0
		_from_pose = _tentacle.path().duplicate()
		_step["do"] = "rest"
		_step["seconds"] = 1.0
	return false

# --- The slam, and the spent tentacle ------------------------------------------------

func _start_slam() -> void:
	_slam = MawSlam.new()
	_slam.name = "MawSlam"
	var frame := _player_frame()
	_rift.add_attacker(_slam, frame["p"])
	_slam.impacted.connect(_on_slam_impacted)
	_frame = _player_frame()
	_frame["center"] = _slam.center
	_step_phase = &"raise"
	push_ups = 0
	var comms := _comms()
	if comms:
		comms.say("boss_slam")

func _on_slam_impacted(_hit: bool) -> void:
	_step_phase = &"spent"
	_phase_time = 0.0
	var comms := _comms()
	if comms:
		comms.say("boss_spent")
	# It cannot afford anything else while the limb is spent. The escort holds still.
	_prune_escort()
	for escort in _escorts:
		if is_instance_valid(escort):
			escort.set_escort_orbit_speed(0.0)

func _run_slam() -> bool:
	if _tentacle == null:
		return true
	var center: Vector3 = _frame.get("center", _frame.get("p", Vector3.ZERO))
	match _step_phase:
		&"raise":
			if not is_instance_valid(_slam):
				_step_phase = &"spent"
				return false
			_tentacle.writhe = 0.25
			var raised := _raised_pose(_frame, center)
			if not _slam.has_impacted() and _slam.fall() <= 0.0:
				_tentacle.set_path(_blend(_from_pose, raised, smoothstep(0.0, 0.9, _slam.rise())) if _from_pose.size() == raised.size() else raised)
			else:
				var fall := _slam.fall()
				_tentacle.set_path(_blend(raised, _floor_pose(_frame, center), fall * fall))
		&"spent":
			_tentacle.writhe = 0.04
			_tentacle.set_path(_floor_pose(_frame, center))
			_tentacle.dim = move_toward(_tentacle.dim, 1.0, 0.05)
			if push_ups >= SPENT_PUSH_UPS:
				# The tenth pulse: it convulses and tears back into the rift.
				_enter_recoil(0.6)
			elif _phase_time >= SPENT_SECONDS - WAKE_WARNING:
				_step_phase = &"waking"
				_phase_time = 0.0
				var comms := _comms()
				if comms:
					comms.say("boss_waking")
		&"waking":
			_tentacle.writhe = 0.35
			_tentacle.dim = move_toward(_tentacle.dim, 0.3, 0.02)
			_tentacle.set_path(_floor_pose(_frame, center))
			if _phase_time >= WAKE_WARNING:
				_enter_recoil(RECOIL_SECONDS)
		&"recoil":
			var span := float(_step.get("recoil_seconds", RECOIL_SECONDS))
			_tentacle.writhe = 0.8
			_tentacle.set_path(_blend(_from_pose, _collapsed(_frame), smoothstep(0.0, span, _phase_time)))
			if _phase_time >= span:
				_step_phase = &"stand"
				_phase_time = 0.0
				_tentacle.visible = false
		&"stand":
			# Nothing comes while the player gets up. Then the limb slides back out.
			if _phase_time >= STAND_UP_SECONDS:
				_prune_escort()
				for escort in _escorts:
					if is_instance_valid(escort):
						escort.set_escort_orbit_speed(ESCORT_ORBIT)
				_tentacle.visible = true
				_tentacle.dim = 0.0
				_from_pose = _collapsed(_player_frame())
				_tentacle.set_path(_from_pose)
				return true
	return false

func _enter_recoil(seconds: float) -> void:
	_step_phase = &"recoil"
	_phase_time = 0.0
	_step["recoil_seconds"] = seconds
	_from_pose = _tentacle.path().duplicate()

# --- The escort --------------------------------------------------------------------

## Calls fresh escorts through the mouth when the ring is thin, ready for the next volley.
func _summon_escort() -> void:
	_prune_escort()
	if _escorts.size() >= 3:
		return
	var fresh: Array[Node3D] = []
	for _i in 4:
		var phantom := _rift.spawn_escort()
		if phantom:
			fresh.append(phantom)
	var ring := _escort_ring()
	for i in fresh.size():
		var escort := fresh[i] as Phantom
		if escort == null:
			continue
		escort.enter_escort(ring["center"], ring["right"], ring["radii"], TAU * (float(i) + 0.5) / fresh.size(), ESCORT_ORBIT)
		_escorts.append(escort)

## The ring breaks: one phantom at a time, in a rhythm the player can count.
func _run_volley() -> bool:
	_prune_escort()
	var interval := 1.1
	while _released < int(_step_time / interval) + 1 and not _escorts.is_empty():
		var escort = _escorts.pop_front()
		escort.release_from_escort()
		_released += 1
	return _escorts.is_empty() and _step_time >= interval

func _prune_escort() -> void:
	_escorts = _escorts.filter(func(escort) -> bool: return is_instance_valid(escort) and escort.is_escorting())

# --- The retreat -------------------------------------------------------------------

func _begin_retreat() -> void:
	stage = Stage.RETREAT
	_clock = 0.0
	_fired.clear()
	if is_instance_valid(_sweep):
		_sweep.call("force_cleanup")
	if is_instance_valid(_slam):
		_slam.force_cleanup()
	_sweep = null
	_slam = null
	# Everything it brought flees back through with it.
	var mouth := _rift.portal_center()
	for phantom in _rift.live_phantoms():
		if phantom is Phantom:
			(phantom as Phantom).enter_escort(mouth, Vector3.RIGHT, Vector2(0.5, 0.5), randf() * TAU, 2.0)
		elif phantom.has_method("force_cleanup"):
			phantom.force_cleanup()
	_escorts.clear()
	if _tentacle:
		_tentacle.visible = true
		_from_pose = _tentacle.path().duplicate()
	var comms := _comms()
	if comms:
		comms.cut_off()
		comms.say("boss_retreat")

func _tick_retreat() -> void:
	if _tentacle:
		_tentacle.writhe = 0.9
		_tentacle.set_path(_blend(_from_pose, _collapsed(_player_frame()), smoothstep(0.0, RETREAT_SECONDS, _clock)))
	_rift.set_rift_scale(_phase_one_scale * lerpf(TORN_SCALE_GAIN, 1.0, smoothstep(0.0, RETREAT_SECONDS, _clock)))
	if _clock >= RETREAT_SECONDS * 0.6:
		for phantom in _rift.live_phantoms():
			if phantom.has_method("force_cleanup"):
				phantom.force_cleanup()
	if _clock >= RETREAT_SECONDS:
		if _tentacle:
			_tentacle.queue_free()
		_tentacle = null
		stage = Stage.DONE
		_rift.release_hold()
		retreated.emit()

# --- The glimpse (a Maw that does not break) -----------------------------------------

func _on_glimpse_seal() -> void:
	if stage != Stage.PHASE_ONE or _rift == null:
		return
	stage = Stage.GLIMPSE
	_clock = 0.0
	_fired.clear()
	# A slower dissolve leaves the limb time to grip the rim and be dragged back.
	_rift.dissolve_rate = 0.28
	_spawn_tentacle()
	_tentacle.base_radius = 0.55
	_tentacle.set_path(_glimpse_pose(0.0))

func _tick_glimpse() -> void:
	if _tentacle == null:
		stage = Stage.DONE
		return
	_tentacle.writhe = 0.25 if _clock < 2.0 else 0.8
	_tentacle.set_path(_glimpse_pose(_clock / GLIMPSE_SECONDS))
	if _beat("chen", 1.4):
		var comms := _comms()
		if comms:
			comms.say("maw_glimpse")
	if _clock >= GLIMPSE_SECONDS:
		_tentacle.queue_free()
		_tentacle = null
		stage = Stage.DONE

## Out of the middle of the mouth, a curl over the rim, a grip, then dragged back through.
func _glimpse_pose(t: float) -> Array[Vector3]:
	var center := _rift.portal_center()
	var half := 2.0 * _rift.rift_scale()
	var toward := _toward_player_from_rift()
	var right := toward.cross(Vector3.UP).normalized()
	var inside := center - toward * 1.5
	var grip: Array[Vector3] = [
		inside,
		center + right * half * 0.25 + toward * 0.8,
		center + right * half * 0.6 + toward * 1.4 + Vector3.UP * 0.4,
		center + right * half * 0.95 + toward * 1.2 + Vector3.UP * 0.9,
		center + right * half * 1.12 + toward * 0.5 + Vector3.UP * 0.8,
		center + right * half * 1.08 - toward * 0.3 + Vector3.UP * 0.4,
	]
	var hidden: Array[Vector3] = []
	for _i in grip.size():
		hidden.append(inside)
	if t < 0.45:
		return _blend(hidden, grip, smoothstep(0.0, 0.45, t))
	if t < 0.6:
		return grip
	return _blend(grip, hidden, smoothstep(0.6, 1.0, t))

# --- Poses ---------------------------------------------------------------------------
# Every pose is six control points from the root in the rift to the tip. All of them keep the
# limb at least two metres from the head except the attacks themselves, which are the point.

func _player_frame() -> Dictionary:
	var head := _head()
	var floor_y := 0.0
	var p := Vector3(head.x, floor_y, head.z)
	var to_rift := _rift.global_position - p if _rift else Vector3.FORWARD * 12.0
	to_rift.y = 0.0
	var distance := maxf(to_rift.length(), 4.0)
	var f := to_rift.normalized() if to_rift.length_squared() > 0.01 else Vector3.FORWARD
	var r := f.cross(Vector3.UP).normalized()
	var half := 2.0 * (_rift.rift_scale() if _rift else 2.0)
	var mouth := _rift.portal_center() if _rift else p + f * distance + Vector3.UP * 4.0
	var root := Vector3(mouth.x, mouth.y - half * 0.55, mouth.z) - f * 0.5
	return {"p": p, "f": f, "r": r, "distance": distance, "root": root, "head": head}

func _collapsed(frame: Dictionary) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for _i in 6:
		points.append(frame["root"])
	return points

func _floor_near_rift(frame: Dictionary) -> Vector3:
	return frame["p"] + frame["f"] * (frame["distance"] - 2.2) + Vector3.UP * 0.35

func _slide_pose(frame: Dictionary, s: float) -> Array[Vector3]:
	var root: Vector3 = frame["root"]
	var near := _floor_near_rift(frame)
	var stop: Vector3 = frame["p"] + frame["f"] * 2.6 + Vector3.UP * 0.35
	var tip := near.lerp(stop, s)
	return [root, root.lerp(near, 0.5) + Vector3.UP * 0.4, near, near.lerp(tip, 0.4), near.lerp(tip, 0.75), tip]

## Up from the floor until the player has to tilt their head back to see the top.
func _rise_pose(frame: Dictionary, u: float) -> Array[Vector3]:
	var root: Vector3 = frame["root"]
	var near := _floor_near_rift(frame)
	var p: Vector3 = frame["p"]
	var f: Vector3 = frame["f"]
	return [
		root,
		root.lerp(near, 0.5) + Vector3.UP * 0.4,
		near,
		p + f * 4.6 + Vector3.UP * 0.35,
		p + f * 2.9 + Vector3.UP * (0.35 + 4.0 * u),
		p + f * (2.6 - 0.3 * u) + Vector3.UP * (0.35 + 7.6 * u),
	]

func _hover_pose(frame: Dictionary) -> Array[Vector3]:
	var root: Vector3 = frame["root"]
	var p: Vector3 = frame["p"]
	var f: Vector3 = frame["f"]
	var r: Vector3 = frame["r"]
	var d: float = frame["distance"]
	var sway := sin(_clock * 0.5) * 1.2
	return [
		root,
		root - f * 1.5 + Vector3.UP * 1.0,
		p + f * (d - 4.5) + Vector3.UP * 4.0 + r * sway * 0.3,
		p + f * 7.0 + Vector3.UP * 5.8 + r * sway * 0.7,
		p + f * 5.6 + Vector3.UP * 5.4 + r * sway,
		p + f * 4.8 + Vector3.UP * 4.6 + r * sway * 1.2,
	]

## The limb lies along the line from the rift past the player, through `line` (a point at its height).
func _sweep_pose(frame: Dictionary, line: Vector3) -> Array[Vector3]:
	var root: Vector3 = frame["root"]
	var f: Vector3 = frame["f"]
	var p: Vector3 = frame["p"]
	var drift := Vector3(line.x - p.x, 0.0, line.z - p.z)
	return [
		root,
		root.lerp(line + f * 6.0, 0.4) + Vector3.UP * 1.0 + drift * 0.2,
		line + f * 5.5 + Vector3.UP * 0.5,
		line + f * 2.5,
		line,
		line - f * 2.2,
	]

## Raised overhead before a slam, the tip above and just in front of where the player stands.
func _raised_pose(frame: Dictionary, center: Vector3) -> Array[Vector3]:
	var root: Vector3 = frame["root"]
	var f: Vector3 = frame["f"]
	var near := _floor_near_rift(frame)
	return [
		root,
		near + Vector3.UP * 2.5,
		center + f * 5.0 + Vector3.UP * 6.0,
		center + f * 2.4 + Vector3.UP * 7.4,
		center + f * 1.1 + Vector3.UP * 7.0,
		center + f * 0.5 + Vector3.UP * 6.0,
	]

## Down along the floor, the tip where the player stood.
func _floor_pose(frame: Dictionary, center: Vector3) -> Array[Vector3]:
	var root: Vector3 = frame["root"]
	var f: Vector3 = frame["f"]
	var near := _floor_near_rift(frame)
	var ground := Vector3(center.x, 0.0, center.z)
	return [
		root,
		root.lerp(near, 0.5) + Vector3.UP * 0.4,
		near,
		ground + f * 3.6 + Vector3.UP * 0.32,
		ground + f * 1.6 + Vector3.UP * 0.24,
		ground + Vector3.UP * 0.16,
	]

func _blend(a: Array[Vector3], b: Array[Vector3], t: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in mini(a.size(), b.size()):
		out.append(a[i].lerp(b[i], t))
	return out

# --- The world, the music, the voice ---------------------------------------------------

func _set_turn_mood(amount: float) -> void:
	_turn_mood = amount
	var arena := get_tree().get_first_node_in_group("ArenaPresentation")
	if arena and arena.has_method("set_boss_mood"):
		var origin := _rift.global_position if _rift else Vector3.ZERO
		arena.set_boss_mood(amount, origin, _head())

func _duck_audio() -> void:
	var bus := AudioServer.get_bus_index(&"SFX")
	if bus < 0:
		return
	_ducked = true
	AudioServer.set_bus_volume_db(bus, AudioServer.get_bus_volume_db(bus) - 24.0)

func _restore_audio() -> void:
	if not _ducked:
		return
	_ducked = false
	var settings := get_node_or_null("/root/GameSettings")
	if settings and settings.has_method("apply_audio"):
		settings.apply_audio()
	else:
		var bus := AudioServer.get_bus_index(&"SFX")
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, AudioServer.get_bus_volume_db(bus) + 24.0)

func _comms() -> Node:
	return get_tree().get_first_node_in_group("ChenComms")

func _music() -> Node:
	return get_tree().get_first_node_in_group("MusicIntensity")

func _head() -> Vector3:
	var player := get_tree().get_first_node_in_group("Player") as Node3D
	var camera := player.get_node_or_null("XRCamera3D") as Node3D if player else null
	if camera:
		return camera.global_position
	return Vector3(0.0, 1.6, 0.0)

func _toward_player_from_rift() -> Vector3:
	var away := _head() - _rift.global_position
	away.y = 0.0
	return away.normalized() if away.length_squared() > 0.01 else Vector3.BACK

func _reduced_flashes() -> bool:
	var settings := get_node_or_null("/root/GameSettings")
	return settings != null and bool(settings.get("reduced_flashes"))
