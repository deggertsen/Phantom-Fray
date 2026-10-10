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
## The head must reach this far below standing for the dip to be a squat.
@export var squat_ratio: float = 0.20
## And stay there this long.
@export var squat_hold_seconds: float = 0.12
## Longer than this below the squat line is a kneel or a sit, not a rep.
@export var max_squat_seconds: float = 6.0
## Horizontal head travel divided by the drop. A squat keeps the head over the feet;
## bending at the waist or lunging sideways moves it further than it falls.
@export var max_travel_per_drop: float = 1.0
## Looking further down than this (degrees) at the bottom reads as bending over to pick something up.
@export var min_pitch_degrees: float = -50.0
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

func _ready() -> void:
	if not debug_enabled or not OS.is_debug_build():
		set_physics_process(false)
		return
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
	sample(camera.position, rad_to_deg(asin(clampf(forward.y, -1.0, 1.0))), delta)
	if _label:
		_label.text = debug_text()

## One step of the detector. Head position is in XROrigin3D space; pitch is where the face points.
## Split from _physics_process so the validation runner can feed it a recorded motion.
func sample(head: Vector3, pitch_degrees: float, delta: float) -> void:
	if delta <= 0.0:
		return
	_last_head = head
	_last_pitch = pitch_degrees
	if not is_nan(_previous_y):
		var measured := (head.y - _previous_y) / delta
		vertical_speed = lerpf(vertical_speed, measured, clampf(delta * 20.0, 0.0, 1.0))
	_previous_y = head.y
	peak_rise_speed = maxf(peak_rise_speed * pow(0.5, delta), vertical_speed)
	var still := absf(vertical_speed) < still_speed
	if state == State.CALIBRATING:
		_calibrate(head.y, still, delta)
		return
	var drop := standing_height - head.y
	depth_ratio = drop / standing_height
	_follow_standing(head.y, still, delta)
	match state:
		State.STANDING:
			if depth_ratio >= dip_ratio:
				state = State.DIPPING
				_dip_start = head
				_dip_time = 0.0
				_below_time = 0.0
				_max_depth = depth_ratio
				_max_travel = 0.0
		State.DIPPING, State.SQUAT, State.HOLD:
			_dip_time += delta
			_max_depth = maxf(_max_depth, depth_ratio)
			var travel := Vector2(head.x - _dip_start.x, head.z - _dip_start.z).length()
			_max_travel = maxf(_max_travel, travel)
			if depth_ratio < dip_ratio:
				_finish_dip()
				return
			if depth_ratio >= squat_ratio:
				_below_time += delta
			if state == State.DIPPING and _below_time >= squat_hold_seconds:
				var reason := _squat_fault(drop, pitch_degrees)
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
	return _squat_fault(standing_height - _last_head.y, _last_pitch)

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

func _squat_fault(drop: float, pitch_degrees: float) -> StringName:
	if drop > 0.0 and _max_travel / drop > max_travel_per_drop:
		return &"leaned_or_stepped"
	if pitch_degrees < min_pitch_degrees:
		return &"looking_at_floor"
	return &""

func _finish_dip() -> void:
	if state == State.SQUAT:
		rep_count += 1
		squat_completed.emit(_max_depth, _dip_time)
	elif state == State.DIPPING and _max_depth < squat_ratio:
		_reject(&"too_shallow")
	state = State.STANDING

func _reject(reason: StringName) -> void:
	last_rejection = reason
	squat_rejected.emit(reason)
	if state == State.DIPPING:
		# Stay out of SQUAT until the head comes back up; the dip is spent.
		state = State.HOLD
