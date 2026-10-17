extends Node
class_name PushUpDetector

## Counts push-ups from head tracking alone, for the boss Maw's spent tentacle (MawBoss connects
## to push_up_completed through the "PushUpDetector" group). See
## development/Exercise_Mechanics_Exploration.md, section 1, "Push-up".
##
## A plank is the head low: below `plank_enter_ratio` of standing eye height to get in, and above
## `plank_exit_ratio` to get out, so the line cannot flicker. A rep is the head falling at least
## `rep_drop` from its highest point in the plank and coming back up by the same amount. Knee
## push-ups count; the game cannot tell, and does not try.
##
## Quest 3, 2026-10-11 (one tester, 1.57 to 1.60 m standing eye height): push-up tops 46 to 57 cm,
## bottoms 11 to 27 cm, 20 to 42 cm of head travel; the deepest squats kept the head at 73 to 80 cm.
## The first version also wanted the face pointed 30 degrees down. Doing push-ups while looking
## forward held the face at 29 to 31 degrees, right on that line, and it dropped in and out of the
## plank dozens of times and lost count; the head height alone separates them.
## Head pose: XRCamera3D.position is in XROrigin3D space, floor at y = 0 (Stage reference space).
##
## With both controllers hanging on their straps and both hands tracked (TrackedHands, decision 39),
## getting into a plank also needs both palms flat and within `palm_floor_height` of the floor, so
## a low crouch with the hands up is not a plank. Leaving the plank stays on head height alone, so
## a hand the cameras lose for a frame cannot end a set. With a controller in either hand, the
## head rule is all there is.

signal push_up_completed
signal plank_changed(in_plank: bool)

enum Palms { UNKNOWN, ON_FLOOR, OFF_FLOOR }

## The head must fall below this share of standing eye height to enter a plank.
@export var plank_enter_ratio: float = 0.38
## And rise above this share to leave it.
@export var plank_exit_ratio: float = 0.48
## A rep is a fall and a rise of at least this much, in metres. Quest 3, 2026-10-11: real reps moved
## the head 22 to 38 cm; getting into and out of the plank made 8 to 9 cm wobbles that 6 cm counted.
@export var rep_drop: float = 0.12
## A palm on the floor: its joint no higher than this above the floor (m). Flat palms sat 2 to 3 cm up.
@export var palm_floor_height: float = 0.1
## Debug builds print a PUSHUP line for every plank and rep, for logcat.
@export var log_reps: bool = true

var camera: Node3D
var in_plank: bool = false
var rep_count: int = 0

var _squat: SquatDetector
var _hands: TrackedHands
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
	_hands = player.get_node_or_null("TrackedHands") as TrackedHands
	_log = log_reps and OS.is_debug_build()

func _physics_process(_delta: float) -> void:
	if camera == null:
		return
	var forward := -camera.transform.basis.z
	sample(camera.position.y, rad_to_deg(asin(clampf(forward.y, -1.0, 1.0))), palms_state())

## Where the palms are, when both controllers hang and the cameras see both hands.
func palms_state() -> Palms:
	if _hands == null:
		return Palms.UNKNOWN
	for side in TrackedHands.SIDES:
		if not _hands.is_free(side) or not _hands.is_tracked(side):
			return Palms.UNKNOWN
	for side in TrackedHands.SIDES:
		if not _hands.is_palm_flat(side) or _hands.palm(side).origin.y > palm_floor_height:
			return Palms.OFF_FLOOR
	return Palms.ON_FLOOR

## One step. Split from _physics_process so the validation runner can feed it a motion.
func sample(head_y: float, pitch_degrees: float, palms: Palms = Palms.UNKNOWN) -> void:
	var standing := _standing_height(head_y)
	var low := head_y < standing * (plank_exit_ratio if in_plank else plank_enter_ratio)
	if low and not in_plank and palms == Palms.OFF_FLOOR:
		low = false
	if low != in_plank:
		in_plank = low
		_top = head_y
		_bottom = head_y
		_going_down = false
		plank_changed.emit(in_plank)
		if _log:
			print("PUSHUP plank %s head=%.3f stand=%.3f pitch=%.0f palms=%s" % [
				"on" if in_plank else "off", head_y, standing, pitch_degrees, Palms.keys()[palms],
			])
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
