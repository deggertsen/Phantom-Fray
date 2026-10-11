extends Node
class_name PushUpDetector

## Counts push-ups from head tracking alone, for the boss Maw's spent tentacle (MawBoss connects
## to push_up_completed through the "PushUpDetector" group). See
## development/Exercise_Mechanics_Exploration.md, section 1, "Push-up".
##
## A plank is the head low and the face toward the floor. A rep is the head falling at least
## `rep_drop` from its highest point in the plank and coming back up by the same amount. On Quest 3
## (2026-10-11) the head sat 12 to 20 cm off the floor through a spent window's push-ups, so the
## plank line is generous. Knee push-ups count; the game cannot tell, and does not try.
## Head pose: XRCamera3D.position is in XROrigin3D space, floor at y = 0 (Stage reference space).

signal push_up_completed
signal plank_changed(in_plank: bool)

## The head must be below this share of standing eye height to be in a plank.
@export var plank_ratio: float = 0.45
## And the face must point at least this far down (degrees below level).
@export var plank_pitch_degrees: float = -30.0
## A rep is a fall and a rise of at least this much, in metres.
@export var rep_drop: float = 0.06
## Debug builds print a PUSHUP line for every plank and rep, for logcat.
@export var log_reps: bool = true

var camera: Node3D
var in_plank: bool = false
var rep_count: int = 0

var _squat: SquatDetector
var _standing_fallback: float = 1.6
var _top: float = 0.0
var _bottom: float = 0.0
var _going_down: bool = false
var _log: bool = false

func _ready() -> void:
	add_to_group("PushUpDetector")
	var player := get_parent()
	camera = player.get_node_or_null("XRCamera3D") as Node3D
	_squat = player.get_node_or_null("SquatDetector") as SquatDetector
	_log = log_reps and OS.is_debug_build()

func _physics_process(_delta: float) -> void:
	if camera == null:
		return
	var forward := -camera.transform.basis.z
	sample(camera.position.y, rad_to_deg(asin(clampf(forward.y, -1.0, 1.0))))

## One step. Split from _physics_process so the validation runner can feed it a motion.
func sample(head_y: float, pitch_degrees: float) -> void:
	var standing := _standing_height(head_y)
	var low := head_y < standing * plank_ratio and pitch_degrees < plank_pitch_degrees
	if low != in_plank:
		in_plank = low
		_top = head_y
		_bottom = head_y
		_going_down = false
		plank_changed.emit(in_plank)
		if _log:
			print("PUSHUP plank %s head=%.3f stand=%.3f pitch=%.0f" % ["on" if in_plank else "off", head_y, standing, pitch_degrees])
	if not in_plank:
		return
	if not _going_down:
		_top = maxf(_top, head_y)
		if head_y <= _top - rep_drop:
			_going_down = true
			_bottom = head_y
	else:
		_bottom = minf(_bottom, head_y)
		if head_y >= _bottom + rep_drop:
			_going_down = false
			rep_count += 1
			if _log:
				print("PUSHUP rep %d top=%.3f bottom=%.3f travel=%.3f pitch=%.0f" % [rep_count, _top, _bottom, _top - _bottom, pitch_degrees])
			_top = head_y
			push_up_completed.emit()

## The SquatDetector's calibrated standing height when it has one; otherwise the highest head
## height seen, which a standing player reaches long before they get down on the floor.
func _standing_height(head_y: float) -> float:
	if _squat and _squat.standing_height > 0.0:
		return _squat.standing_height
	if head_y >= 1.0:
		_standing_fallback = maxf(_standing_fallback, head_y)
	return _standing_fallback
