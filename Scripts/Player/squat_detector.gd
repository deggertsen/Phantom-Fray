extends Node
class_name SquatDetector

## Prototype: reports squats from head height alone, against a calibrated standing height.
## Off by default. Turn on `debug_enabled` on the Player's SquatDetector node in a debug build
## to see the state, depth, and rep count on a label over the right wrist.
## See development/Exercise_Mechanics_Exploration.md for the thresholds and what to test.
##
## XRCamera3D.position is the head in XROrigin3D space. With the default Stage reference space
## the origin sits on the Guardian floor, so position.y is eye height above that floor.
## https://docs.godotengine.org/en/stable/tutorials/xr/openxr_settings.html

signal calibrated(standing_height: float)
signal squat_reached(depth_ratio: float)
signal squat_completed(depth_ratio: float, seconds: float)
signal squat_rejected(reason: StringName)

enum State { CALIBRATING, STANDING, DIPPING, SQUAT, HOLD }

@export var debug_enabled: bool = false
## A dip starts once the head is this far below standing, as a share of standing eye height.
@export var dip_ratio: float = 0.06
## The head must reach this far below standing for the dip to be a squat. Quest 3, 2026-10-09:
## squats reached 45 to 53 %, the shallowest "shallow duck" 20 %.
@export var squat_ratio: float = 0.25
## And stay there this long.
@export var squat_hold_seconds: float = 0.12
## Longer than this below the squat line is a kneel or a sit, not a rep.
@export var max_squat_seconds: float = 6.0
## Most horizontal head travel during the dip divided by the drop. A squat keeps the head over
## the feet; lunging sideways moves it further than it falls. Quest 3: squats 0.04 to 0.15,
## side-step ducks 0.82 to 2.44. Waist bends stayed under 0.3, so this does not catch them.
@export var max_travel_per_drop: float = 0.5
## Looking further down than this (degrees) at any point in the dip reads as bending over.
## Quest 3: squats never went below -5, waist bends always reached -32 or lower (most -75 to -87).
@export var min_pitch_degrees: float = -30.0
## Early arc: horizontal head travel from where the player last stood tall, divided by the drop,
## measured once the head is `early_ratio` of standing height down. A bow pivots at the hips, so
## the head swings forward before it falls; a squat starts straight down. Unlike pitch, looking up
## at an opponent while bowing does not hide it. Starting value; tune from the SQUAT path lines.
@export var max_early_travel_per_drop: float = 0.9
@export var early_ratio: float = 0.08
## Head vertical speed under this counts as still, for calibration.
@export var still_speed: float = 0.15
@export var calibration_seconds: float = 1.0
## Nobody standing in a Quest has eyes lower than this. Below it, the floor or the pose is wrong.
@export var min_standing_height: float = 1.0
## Standing height follows still, upright samples with this time constant.
@export var standing_follow_seconds: float = 3.0
## If the head never comes back near standing for this long, recalibrate from recent peaks.
@export var standing_reset_seconds: float = 15.0

var camera: Node3D
var standing_height: float = -1.0
var state: State = State.CALIBRATING
var rep_count: int = 0
var depth_ratio: float = 0.0
var vertical_speed: float = 0.0
var peak_rise_speed: float = 0.0
var last_rejection: StringName = &""

var _previous_y: float = NAN
var _calibration_samples: PackedFloat32Array = PackedFloat32Array()
var _calibration_time: float = 0.0
var _dip_start: Vector3 = Vector3.ZERO
var _dip_time: float = 0.0
var _below_time: float = 0.0
var _max_depth: float = 0.0
var _max_travel: float = 0.0
var _far_from_standing: float = 0.0
var _recent_peak: float = -1.0
var _last_head: Vector3 = Vector3.ZERO
var _last_pitch: float = 0.0
var _label: Label3D
## Debug only: every dip, rise, and calibration goes to the log as a SQUAT line, so a headset
## session can be read back with `adb logcat -s godot` instead of from the wrist.
var _log: bool = false
var _min_pitch: float = 0.0
var _rise_peak: float = 0.0
var _rise_top: float = 0.0
var _rise_time: float = 0.0
var _logged_standing: float = -1.0
## Where the head was, flat, the last time the player stood tall, and which way they faced.
var _stand_xz: Vector2 = Vector2.ZERO
var _stand_facing: Vector2 = Vector2.ZERO
var _early_travel_per_drop: float = -1.0
const PATH_DEPTHS: Array[float] = [0.05, 0.10, 0.15, 0.20, 0.30]
var _path: PackedStringArray = PackedStringArray()

func _ready() -> void:
	if not debug_enabled or not OS.is_debug_build():
		set_physics_process(false)
		return
	_log = true
	var player := get_parent()
	camera = player.get_node_or_null("XRCamera3D") as Node3D
	var wrist := player.get_node_or_null("RightHandController") as Node3D
	if wrist:
		_label = Label3D.new()
		_label.name = "SquatDebugLabel"
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.pixel_size = 0.0007
		_label.font_size = 32
		_label.outline_size = 8
		_label.no_depth_test = true
		_label.position = Vector3(0.0, 0.1, 0.02)
		wrist.add_child(_label)

func _physics_process(delta: float) -> void:
	if camera == null:
		return
	var forward := -camera.transform.basis.z
	sample(camera.position, rad_to_deg(asin(clampf(forward.y, -1.0, 1.0))), delta, Vector2(forward.x, forward.z))
	if _label:
		_label.text = debug_text()

## One step of the detector. Head position is in XROrigin3D space; pitch is where the face points.
## Split from _physics_process so the validation runner can feed it a recorded motion.
func sample(head: Vector3, pitch_degrees: float, delta: float, facing: Vector2 = Vector2.ZERO) -> void:
	if delta <= 0.0:
		return
	_last_head = head
	_last_pitch = pitch_degrees
	if not is_nan(_previous_y):
		var measured := (head.y - _previous_y) / delta
		vertical_speed = lerpf(vertical_speed, measured, clampf(delta * 20.0, 0.0, 1.0))
		if _log and absf(head.y - _previous_y) > 0.05:
			print("SQUAT head_jump from=%.3f to=%.3f" % [_previous_y, head.y])
	_previous_y = head.y
	peak_rise_speed = maxf(peak_rise_speed * pow(0.5, delta), vertical_speed)
	var still := absf(vertical_speed) < still_speed
	if state == State.CALIBRATING:
		_calibrate(head.y, still, delta)
		return
	var drop := standing_height - head.y
	depth_ratio = drop / standing_height
	_follow_standing(head.y, still, delta)
	_track_arc(head, facing)
	if _log:
		_log_rise(head.y, delta)
		if absf(standing_height - _logged_standing) > 0.02:
			_logged_standing = standing_height
			print("SQUAT stand=%.3f head=%.3f" % [standing_height, head.y])
	match state:
		State.STANDING:
			if depth_ratio >= dip_ratio:
				state = State.DIPPING
				_dip_start = head
				_dip_time = 0.0
				_below_time = 0.0
				_max_depth = depth_ratio
				_max_travel = 0.0
				_min_pitch = pitch_degrees
		State.DIPPING, State.SQUAT, State.HOLD:
			_dip_time += delta
			_max_depth = maxf(_max_depth, depth_ratio)
			_min_pitch = minf(_min_pitch, pitch_degrees)
			var travel := Vector2(head.x - _dip_start.x, head.z - _dip_start.z).length()
			_max_travel = maxf(_max_travel, travel)
			if depth_ratio < dip_ratio:
				_finish_dip()
				return
			if depth_ratio >= squat_ratio:
				_below_time += delta
			if state == State.DIPPING and _below_time >= squat_hold_seconds:
				var reason := _squat_fault(drop, _min_pitch)
				if reason == &"":
					state = State.SQUAT
					squat_reached.emit(_max_depth)
				else:
					_reject(reason)
			elif state == State.SQUAT and _below_time > max_squat_seconds:
				state = State.HOLD
				_reject(&"held_too_long")

## Throw away the current standing height and measure again.
func calibrate_now() -> void:
	state = State.CALIBRATING
	standing_height = -1.0
	_calibration_samples.clear()
	_calibration_time = 0.0

## Why the dip in progress is not a clean squat, judged now at whatever depth it has reached:
## `leaned_or_stepped`, `looking_at_floor`, or "" when it is clean or there is no dip.
## A resonance sweep at duck depth asks for less than a squat, so it asks this instead of waiting for SQUAT.
func dip_fault() -> StringName:
	if state == State.CALIBRATING or state == State.STANDING:
		return &""
	return _squat_fault(maxf(standing_height - _last_head.y, _max_depth * standing_height), _min_pitch)

func debug_text() -> String:
	if state == State.CALIBRATING:
		return "SQUAT DEBUG\nCALIBRATING — STAND STILL\nhead %.2f m" % _previous_y
	return "SQUAT DEBUG  %s\nreps %d   depth %d%%\nstand %.2f  head %.2f\nvy %+.2f  peak up %.2f\nlast reject: %s" % [
		State.keys()[state],
		rep_count,
		int(round(depth_ratio * 100.0)),
		standing_height,
		_previous_y,
		vertical_speed,
		peak_rise_speed,
		last_rejection if last_rejection != &"" else "-",
	]

func _calibrate(height: float, still: bool, delta: float) -> void:
	if not still or height < min_standing_height:
		return
	_calibration_time += delta
	_calibration_samples.append(height)
	if _calibration_time < calibration_seconds:
		return
	var sorted := _calibration_samples.duplicate()
	sorted.sort()
	standing_height = sorted[int(sorted.size() * 0.5)]
	_recent_peak = standing_height
	_far_from_standing = 0.0
	state = State.STANDING
	if _log:
		_logged_standing = standing_height
		print("SQUAT calibrated stand=%.3f samples=%d" % [standing_height, sorted.size()])
	calibrated.emit(standing_height)

## Standing height drifts with posture and fatigue. Still, upright samples pull it;
## squats and jumps are never still, so they do not.
func _follow_standing(height: float, still: bool, delta: float) -> void:
	if not still or height < min_standing_height:
		_far_from_standing += delta
	elif absf(height - standing_height) <= standing_height * dip_ratio:
		standing_height = lerpf(standing_height, height, 1.0 - exp(-delta / standing_follow_seconds))
		_far_from_standing = 0.0
		_recent_peak = height
	else:
		_far_from_standing += delta
		_recent_peak = maxf(_recent_peak, height)
	if _far_from_standing > standing_reset_seconds and _recent_peak >= min_standing_height:
		standing_height = _recent_peak
		_far_from_standing = 0.0
		_recent_peak = -1.0

## Follows the head from where the player last stood tall: records the early-arc ratio once the
## head is `early_ratio` down, and (debug) the forward and sideways travel at each PATH_DEPTHS depth.
func _track_arc(head: Vector3, facing: Vector2) -> void:
	var flat := Vector2(head.x, head.z)
	if depth_ratio < 0.02:
		_stand_xz = flat
		if facing.length_squared() > 0.01:
			_stand_facing = facing.normalized()
		_early_travel_per_drop = -1.0
		_path.clear()
		return
	var offset := flat - _stand_xz
	if _early_travel_per_drop < 0.0 and depth_ratio >= early_ratio:
		_early_travel_per_drop = offset.length() / maxf(depth_ratio * standing_height, 0.001)
	if _log and _path.size() < PATH_DEPTHS.size() and depth_ratio >= PATH_DEPTHS[_path.size()]:
		var forward := offset.dot(_stand_facing)
		var side := offset.dot(Vector2(-_stand_facing.y, _stand_facing.x))
		_path.append("%d%%:f%+.2f/s%+.2f" % [int(PATH_DEPTHS[_path.size()] * 100.0), forward, side])

func _squat_fault(drop: float, pitch_degrees: float) -> StringName:
	if _early_travel_per_drop > max_early_travel_per_drop:
		return &"bowed"
	if drop > 0.0 and _max_travel / drop > max_travel_per_drop:
		return &"leaned_or_stepped"
	if pitch_degrees < min_pitch_degrees:
		return &"looking_at_floor"
	return &""

func _finish_dip() -> void:
	var outcome := "rejected:%s" % last_rejection
	# Judged again over the whole dip: on Quest 3 a waist bend crossed the squat line with the eyes
	# still level and only looked at the floor afterwards, so the check at that moment passed it.
	var late_fault := _squat_fault(_max_depth * standing_height, _min_pitch) if state == State.SQUAT else &""
	if late_fault != &"":
		_reject(late_fault)
		outcome = "rejected:%s" % late_fault
	elif state == State.SQUAT:
		rep_count += 1
		outcome = "rep"
		squat_completed.emit(_max_depth, _dip_time)
	elif state == State.DIPPING and _max_depth < squat_ratio:
		_reject(&"too_shallow")
		outcome = "too_shallow"
	if _log:
		var drop := _max_depth * standing_height
		print("SQUAT dip %s reps=%d depth=%.2f drop=%.3f travel=%.3f travel_per_drop=%.2f early=%.2f min_pitch=%.0f secs=%.2f" % [
			outcome, rep_count, _max_depth, drop, _max_travel, _max_travel / maxf(drop, 0.001), _early_travel_per_drop, _min_pitch, _dip_time,
		])
		print("SQUAT path %s" % " ".join(_path))
	state = State.STANDING

## Debug log of every rise above standing: peak upward speed, height above standing, time up.
## Test 3 (jumps against calf raises) reads these.
func _log_rise(height: float, delta: float) -> void:
	var above := height - standing_height
	if above > 0.02:
		if _rise_time == 0.0:
			# Takeoff speed peaks just before the head clears standing; peak_rise_speed still holds it.
			_rise_peak = peak_rise_speed
		_rise_time += delta
		_rise_top = maxf(_rise_top, above)
		_rise_peak = maxf(_rise_peak, vertical_speed)
	elif _rise_time > 0.0:
		print("SQUAT rise peak_up=%.2f above=%.3f secs=%.2f" % [_rise_peak, _rise_top, _rise_time])
		_rise_time = 0.0
		_rise_top = 0.0
		_rise_peak = 0.0

func _reject(reason: StringName) -> void:
	last_rejection = reason
	squat_rejected.emit(reason)
	if state == State.DIPPING:
		# Stay out of SQUAT until the head comes back up; the dip is spent.
		state = State.HOLD
