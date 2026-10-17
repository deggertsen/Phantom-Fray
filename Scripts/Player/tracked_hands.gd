extends Node
class_name TrackedHands

## Simultaneous hands and controllers (decision 39 in development/Exercise_Mechanics_Exploration.md):
## the player fights on the controllers and lets them hang on their wrist straps for the floor,
## where the headset tracks the bare hands. This node keeps XR_META_simultaneous_hands_and_controllers
## running, and says for each hand whether it has let go of its controller ("free"), where its
## palm is, how far its fingers are curled, and whether the palm lies flat.
##
## A hand is free when its hand tracker is fed by the cameras (`HAND_TRACKING_SOURCE_UNOBSTRUCTED`).
## The controller's own pose cannot say this: a controller put down on a table, or hanging on its
## strap, still reports a tracked pose (Quest 3, 2026-10-14). Gripping the controller turns the
## source to `HAND_TRACKING_SOURCE_CONTROLLER` within a frame, and the hand stops being free.
##
## Quest 3, tests 7 and 8 (2026-10-14 and 2026-10-17): a released controller gives an optical
## hand 0.43 s after simultaneous tracking resumes; held fists curl 0.97 to 1.00 and open hands
## 0.08 to 0.14; palms flat on the floor held 26 of 26 joints with no drops. The runtime starts
## every session with simultaneous tracking paused, so it is resumed on each `session_begun`.
##
## https://docs.godotengine.org/en/4.7/classes/class_xrhandtracker.html
## https://github.com/GodotVR/godot_openxr_vendors/blob/5.1.0-stable/doc_classes/OpenXRMetaSimultaneousHandsAndControllersExtension.xml

signal hand_freed(side: StringName, free: bool)

const SIMULTANEOUS_SINGLETON := "OpenXRMetaSimultaneousHandsAndControllersExtension"
const FINGER_COUNT := 4
const JOINTS_PER_FINGER := 5
const SIDES: Array[StringName] = [&"left", &"right"]

## Resume simultaneous tracking whenever an OpenXR session begins.
@export var simultaneous_enabled: bool = true
## The cameras must see the hand this long before it counts as free (s).
@export var free_after_seconds: float = 0.1
## A free hand the cameras lose stays free this long (s), so a flicker does not snap the
## gauntlet back to the hanging controller. Gripping the controller ends it at once.
@export var keep_free_seconds: float = 0.6
## Total bend of a finger's three knuckles (degrees) that reads as fully curled.
@export var full_curl_degrees: float = 240.0
## Mean curl at or above this is a closed fist.
@export var fist_curl: float = 0.65
## A palm is flat when its back-of-hand axis is within this many degrees of vertical.
@export var flat_palm_degrees: float = 35.0
## The held-controller pose is measured only while the controller moves slower than this (m/s)
@export var grip_still_speed: float = 0.3
## and turns slower than this (rad/s).
@export var grip_still_turn: float = 1.5

class HandState:
	var free: bool = false
	var tracked: bool = false
	var optical_seconds: float = 0.0
	var lost_seconds: float = 0.0
	## The hand frame (see hand_frame), in play space, last tracked.
	var palm: Transform3D = Transform3D.IDENTITY
	var curl: float = 0.0
	## Thumb tip to index tip (m), last tracked.
	var pinch: float = 1.0
	## The controller's pose in the hand frame, measured while the controller is held.
	var grip_in_palm: Transform3D = Transform3D.IDENTITY
	var grip_measured: bool = false

var simultaneous_running: bool = false
var _hands: Dictionary = {}
var _log: bool = false
var _log_clock: float = 0.0

func _init() -> void:
	for side in SIDES:
		_hands[side] = HandState.new()

func _ready() -> void:
	add_to_group("TrackedHands")
	# Read the hands before the controllers place their visuals this frame.
	process_priority = -10
	_log = OS.is_debug_build()
	var openxr := XRServer.find_interface("OpenXR") as OpenXRInterface
	if openxr:
		openxr.session_begun.connect(_on_session_begun)

func _process(delta: float) -> void:
	_log_clock -= delta
	for side in SIDES:
		_read_hand(side, delta)
	if _log_clock <= 0.0:
		_log_clock = 1.0

func is_free(side: StringName) -> bool:
	var hand: HandState = _hands.get(side)
	return hand != null and hand.free

## True while the cameras track this hand right now (not just within the free grace).
func is_tracked(side: StringName) -> bool:
	var hand: HandState = _hands.get(side)
	return hand != null and hand.tracked

## The hand frame in play space: origin on the palm, axes laid out like controller space.
func palm(side: StringName) -> Transform3D:
	var hand: HandState = _hands.get(side)
	return hand.palm if hand else Transform3D.IDENTITY

## Mean finger curl, 0 open to 1 fully closed. Only meaningful while the hand is tracked.
func curl(side: StringName) -> float:
	var hand: HandState = _hands.get(side)
	return hand.curl if hand else 0.0

## Thumb tip to index tip (m) while the cameras track the hand; -1 when they do not.
func pinch_gap(side: StringName) -> float:
	var hand: HandState = _hands.get(side)
	return hand.pinch if hand and hand.tracked else -1.0

## Where the held controller sits in the hand frame, as the runtime places a hand around a held
## controller. False until it has been measured.
func has_grip_in_palm(side: StringName) -> bool:
	var hand: HandState = _hands.get(side)
	return hand != null and hand.grip_measured

func grip_in_palm(side: StringName) -> Transform3D:
	var hand: HandState = _hands.get(side)
	return hand.grip_in_palm if hand else Transform3D.IDENTITY

func is_palm_flat(side: StringName) -> bool:
	return is_tracked(side) and palm_is_flat(palm(side), flat_palm_degrees)

## A palm lies flat when the hand frame's back-of-hand axis (X) is near vertical. Either way up
## counts: a palm turned up on the floor is still on the floor.
static func palm_is_flat(frame: Transform3D, max_degrees: float) -> bool:
	var back := frame.basis.x.normalized()
	return absf(back.dot(Vector3.UP)) >= cos(deg_to_rad(max_degrees))

## A frame for the hand built from joint positions only, so it does not depend on how the runtime
## or Godot orients the joints (the palm joint's rotation differed between a camera-tracked hand and
## one built around a held controller on Quest 3, 2026-10-17). Its axes match controller space:
## -Z runs from the wrist toward the middle knuckle, +Y from the pinky knuckle toward the index
## knuckle (the thumb side), and X = Y x Z, the back of the hand on a right hand and the palm on
## a left one. The origin is the palm joint.
static func frame_from_points(wrist: Vector3, middle_knuckle: Vector3, index_knuckle: Vector3,
		pinky_knuckle: Vector3, palm_center: Vector3) -> Transform3D:
	var z := wrist - middle_knuckle
	var y := index_knuckle - pinky_knuckle
	if z.length_squared() < 1e-8 or y.length_squared() < 1e-8:
		return Transform3D(Basis.IDENTITY, palm_center)
	z = z.normalized()
	y = (y - z * y.dot(z)).normalized()
	return Transform3D(Basis(y.cross(z), y, z), palm_center)

static func hand_frame(tracker: XRHandTracker) -> Transform3D:
	return frame_from_points(
		tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_WRIST).origin,
		tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_PROXIMAL).origin,
		tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL).origin,
		tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_PROXIMAL).origin,
		tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM).origin)

## Curl of one finger from 0 (straight) to 1 (fully bent), from its metacarpal, proximal,
## intermediate, distal, and tip joint positions: the bend at its three knuckles, added up.
static func finger_curl(points: PackedVector3Array, full_degrees: float = 240.0) -> float:
	if points.size() < JOINTS_PER_FINGER:
		return 0.0
	var bend := 0.0
	for i in range(1, JOINTS_PER_FINGER - 1):
		var a := points[i] - points[i - 1]
		var b := points[i + 1] - points[i]
		if a.length_squared() > 0.0 and b.length_squared() > 0.0:
			bend += rad_to_deg(a.angle_to(b))
	return clampf(bend / full_degrees, 0.0, 1.0)

## Mean curl of index, middle, ring, and pinky from a hand tracker; the thumb is left out.
static func hand_curl(tracker: XRHandTracker, full_degrees: float = 240.0) -> float:
	var total := 0.0
	for finger in FINGER_COUNT:
		var points := PackedVector3Array()
		var first: int = XRHandTracker.HAND_JOINT_INDEX_FINGER_METACARPAL + finger * JOINTS_PER_FINGER
		for joint in range(first, first + JOINTS_PER_FINGER):
			points.append(tracker.get_hand_joint_transform(joint as XRHandTracker.HandJoint).origin)
		total += finger_curl(points, full_degrees)
	return total / FINGER_COUNT

func simultaneous_supported() -> bool:
	if not Engine.has_singleton(SIMULTANEOUS_SINGLETON):
		return false
	return Engine.get_singleton(SIMULTANEOUS_SINGLETON).is_simultaneous_hands_and_controllers_supported()

## Resumes or pauses XR_META_simultaneous_hands_and_controllers. Without it, letting go of one
## controller leaves that hand untracked while the other holds its controller.
func set_simultaneous(running: bool) -> void:
	if not simultaneous_supported():
		simultaneous_running = false
		return
	var extension := Engine.get_singleton(SIMULTANEOUS_SINGLETON)
	if running:
		extension.resume_simultaneous_hands_and_controllers_tracking()
	else:
		extension.pause_simultaneous_hands_and_controllers_tracking()
	simultaneous_running = running

func _on_session_begun() -> void:
	if simultaneous_enabled:
		set_simultaneous(true)

func _read_hand(side: StringName, delta: float) -> void:
	var tracker := XRServer.get_tracker(StringName("/user/hand_tracker/%s" % side)) as XRHandTracker
	var optical := false
	if tracker and tracker.has_tracking_data:
		var palm_flags := tracker.get_hand_joint_flags(XRHandTracker.HAND_JOINT_PALM)
		optical = tracker.hand_tracking_source == XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED \
			and bool(palm_flags & XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED)
	var gripped := tracker != null and tracker.hand_tracking_source == XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER
	var hand: HandState = _hands[side]
	if optical:
		hand.palm = hand_frame(tracker)
		hand.curl = hand_curl(tracker, full_curl_degrees)
		hand.pinch = tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_THUMB_TIP).origin.distance_to(
			tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP).origin)
	if gripped and tracker.has_tracking_data:
		_measure_grip(side, hand, tracker)
	step(side, delta, optical, gripped)

## One step of the free/held decision. Split from _process so the validation runner can drive it.
func step(side: StringName, delta: float, optical: bool, gripped: bool) -> void:
	var hand: HandState = _hands[side]
	hand.tracked = optical
	if optical:
		hand.optical_seconds += delta
		hand.lost_seconds = 0.0
	else:
		hand.optical_seconds = 0.0
		hand.lost_seconds += delta
	var free := hand.free
	if gripped:
		free = false
	elif optical and hand.optical_seconds >= free_after_seconds:
		free = true
	elif not optical and hand.lost_seconds >= keep_free_seconds:
		free = false
	if free != hand.free:
		hand.free = free
		if _log:
			print("HANDS %s %s" % [side, "free" if free else "held"])
		hand_freed.emit(side, free)

## While the controller is held, the runtime builds the hand around it (source CONTROLLER). The
## controller's pose in that hand's frame is where the glove has to sit on a free hand.
func _measure_grip(side: StringName, hand: HandState, tracker: XRHandTracker) -> void:
	var controller := XRServer.get_tracker(StringName("%s_hand" % side)) as XRPositionalTracker
	var pose := controller.get_pose(&"default") if controller else null
	if pose == null or not pose.has_tracking_data:
		return
	# Only a firm, still grip. While the controller is let go it swings, and the hand the runtime
	# builds around it lags a frame behind: measured then, the pose came out 70 to 90 degrees off
	# (Quest 3, 2026-10-17).
	if not bool(controller.get_input("grip_click")) or pose.linear_velocity.length() > grip_still_speed \
			or pose.angular_velocity.length() > grip_still_turn:
		return
	hand.grip_in_palm = hand_frame(tracker).affine_inverse() * pose.transform
	hand.grip_measured = true
	if _log and _log_clock <= 0.0:
		var b := hand.grip_in_palm.basis.orthonormalized()
		print("HANDS grip_in_palm %s x=%s y=%s z=%s o=%s" % [side, b.x.snapped(Vector3.ONE * 0.01),
			b.y.snapped(Vector3.ONE * 0.01), b.z.snapped(Vector3.ONE * 0.01), hand.grip_in_palm.origin.snapped(Vector3.ONE * 0.001)])
