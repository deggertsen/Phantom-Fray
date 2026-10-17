extends Node
class_name HandTrackingProbe

## Measurement build only: reads Quest hand tracking through XRServer and shows, for each hand,
## whether the tracker is there, how well its joints are tracked, palm speed, a fist reading from
## finger curl, dropped poses, and which input the hand is using. It answers tests 7 and 8 in
## section 3 of development/Exercise_Mechanics_Exploration.md. It does not touch combat.
##
## Off by default. On in a debug build when `debug_enabled` is set, or when the project setting
## `phantom_fray/debug/hand_tracking_probe` is true (tools/build_quest_debug.ps1 -HandTrackingTest
## sets it, along with the OpenXR hand tracking settings, for that one export).
##
## Left thumbstick click: pause or resume XR_META_simultaneous_hands_and_controllers.
## Right thumbstick click: reset the counters.
## Every punch, drop, change of input, and change of confidence is also printed with a HANDTEST
## prefix, for `adb logcat -s godot`. Punch and drop lines carry the finger curl and where the palm
## was relative to the head (degrees right and up of straight ahead), to show fists and the edges
## of the camera view without the overlay.
##
## https://docs.godotengine.org/en/4.7/classes/class_xrhandtracker.html
## https://github.com/GodotVR/godot_openxr_vendors/blob/5.1.0-stable/doc_classes/OpenXRMetaSimultaneousHandsAndControllersExtension.xml

const SETTING := "phantom_fray/debug/hand_tracking_probe"

@export var debug_enabled: bool = false
## A punch starts when the palm moves faster than this (m/s).
@export var punch_start_speed: float = 1.5
## It counts as a punch if it peaks at or above this, or if tracking dropped during it.
@export var punch_speed: float = 2.5
## It ends when the palm slows below this.
@export var punch_end_speed: float = 0.8
## Or when tracking has been gone this long.
@export var punch_lost_seconds: float = 0.3
## A frame-to-frame speed above this is a pose jump (the tracker teleported), not a hand.
@export var jump_speed: float = 25.0
## Total bend of a finger's three knuckles (degrees) that reads as fully curled.
@export var full_curl_degrees: float = 240.0
## Mean curl of the four fingers at or above this is a closed fist.
@export var fist_curl: float = 0.65
## Window for the peak speed readout.
@export var peak_window_seconds: float = 1.0
## How often both hands' state is printed to logcat.
@export var state_log_seconds: float = 0.5

class Hand:
	var side: StringName
	var hand_tracker_name: StringName
	var controller_tracker_name: StringName
	var present: bool = false
	var tracked: bool = false
	var source: int = XRHandTracker.HAND_TRACKING_SOURCE_UNKNOWN
	var confidence: int = XRPose.XR_TRACKING_CONFIDENCE_NONE
	var joints_tracked: int = 0
	var reported_valid: bool = false
	var reported_speed: float = 0.0
	var computed_speed: float = 0.0
	var curl: float = 0.0
	var fist: bool = false
	var controller_tracked: bool = false
	var controller_profile: String = ""
	var drops: int = 0
	var jumps: int = 0
	var punches: int = 0
	var dropped_punches: int = 0
	var peak_reported: float = 0.0
	var peak_computed: float = 0.0
	var history: PackedVector3Array = PackedVector3Array()
	var last_palm: Vector3 = Vector3.ZERO
	var has_last: bool = false
	var in_punch: bool = false
	var punch_peak_reported: float = 0.0
	var punch_peak_computed: float = 0.0
	var punch_dropped: bool = false
	var punch_min_curl: float = 1.0
	var lost_seconds: float = 0.0
	## Palm direction from the head while tracked: degrees right (x) and up (y) of straight ahead.
	var view: Vector2 = Vector2.ZERO
	var last_input: String = ""
	var last_confidence: int = -1

	func _init(hand_side: StringName) -> void:
		side = hand_side
		hand_tracker_name = StringName("/user/hand_tracker/%s" % hand_side)
		controller_tracker_name = StringName("%s_hand" % hand_side)

	func reset_counters() -> void:
		drops = 0
		jumps = 0
		punches = 0
		dropped_punches = 0
		in_punch = false

	## Which input drives this hand right now. BOTH means the controller is tracked
	## (in the hand or hanging on its strap) and the hand is tracked by the cameras.
	func input_name() -> String:
		var optical := tracked and source != XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER
		if controller_tracked and optical:
			return "BOTH"
		if controller_tracked:
			return "CONTROLLER"
		if optical:
			return "HAND"
		return "NONE"

var hands: Array[Hand] = [Hand.new(&"left"), Hand.new(&"right")]
var _tracked_hands: TrackedHands
var _label: Label3D
var _time: float = 0.0
var _state_timer: float = 0.0

func _ready() -> void:
	if not is_enabled():
		set_process(false)
		return
	var player := get_parent()
	_tracked_hands = player.get_node_or_null("TrackedHands") as TrackedHands
	_label = Label3D.new()
	_label.name = "HandTrackingProbeLabel"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0007
	_label.font_size = 28
	_label.outline_size = 8
	_label.no_depth_test = true
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.position = Vector3(0.0, 1.0, -0.7)
	player.add_child.call_deferred(_label)
	for hand in hands:
		player.add_child.call_deferred(_palm_marker(hand))
	var left := player.get_node_or_null("LeftHandController") as XRController3D
	var right := player.get_node_or_null("RightHandController") as XRController3D
	if left:
		left.button_pressed.connect(_on_left_button)
	if right:
		right.button_pressed.connect(_on_right_button)
	print("HANDTEST probe on. hand_tracking=%s simultaneous_ext=%s" % [
		ProjectSettings.get_setting_with_override("xr/openxr/extensions/hand_tracking"),
		ProjectSettings.get_setting_with_override("xr/openxr/extensions/meta/simultaneous_hands_and_controllers"),
	])

func is_enabled() -> bool:
	return OS.is_debug_build() and (debug_enabled or bool(ProjectSettings.get_setting(SETTING, false)))

func _process(delta: float) -> void:
	_time += delta
	for hand in hands:
		_read_hand(hand, delta)
	if _label:
		_label.text = debug_text()
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state_timer = state_log_seconds
		_log_state()

## A steady readout of both hands (input, confidence, joints, curl, palm direction) so a held
## fist, an open hand, or a hand near the face can be read from logcat.
func _log_state() -> void:
	var parts := PackedStringArray()
	for hand in hands:
		parts.append("%s %s %s j%d curl=%.2f view=%+.0f,%+.0f" % [
			String(hand.side).left(1).to_upper(), hand.input_name(), _confidence_name(hand.confidence),
			hand.joints_tracked, hand.curl, hand.view.x, hand.view.y,
		])
	print("HANDTEST state t=%.2f %s" % [_time, " | ".join(parts)])

## Reads one hand from XRServer and feeds the measurement.
func _read_hand(hand: Hand, delta: float) -> void:
	var controller := XRServer.get_tracker(hand.controller_tracker_name) as XRPositionalTracker
	hand.controller_profile = controller.profile.get_file() if controller else ""
	var controller_pose: XRPose = controller.get_pose(&"default") if controller else null
	hand.controller_tracked = controller_pose != null and controller_pose.has_tracking_data \
		and controller_pose.tracking_confidence != XRPose.XR_TRACKING_CONFIDENCE_NONE
	var tracker := XRServer.get_tracker(hand.hand_tracker_name) as XRHandTracker
	hand.present = tracker != null
	if tracker == null:
		sample_hand(hand, _time, delta, false, Vector3.ZERO, Vector3.ZERO, false)
		return
	hand.source = tracker.hand_tracking_source
	var pose := tracker.get_pose(&"default")
	hand.confidence = pose.tracking_confidence if pose else XRPose.XR_TRACKING_CONFIDENCE_NONE
	hand.joints_tracked = 0
	for joint in XRHandTracker.HAND_JOINT_MAX:
		if tracker.get_hand_joint_flags(joint as XRHandTracker.HandJoint) &XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED:
			hand.joints_tracked += 1
	var palm_flags := tracker.get_hand_joint_flags(XRHandTracker.HAND_JOINT_PALM)
	var tracked := tracker.has_tracking_data and bool(palm_flags & XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED)
	var palm := tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM).origin
	var velocity_valid := bool(palm_flags & XRHandTracker.HAND_JOINT_FLAG_LINEAR_VELOCITY_VALID)
	var velocity := tracker.get_hand_joint_linear_velocity(XRHandTracker.HAND_JOINT_PALM)
	if tracked:
		var camera := get_viewport().get_camera_3d()
		if camera:
			var local := camera.global_transform.affine_inverse() * (get_parent() as Node3D).global_transform * palm
			hand.view = Vector2(rad_to_deg(atan2(local.x, -local.z)), rad_to_deg(atan2(local.y, -local.z)))
		set_curl(hand, PackedFloat32Array([TrackedHands.hand_curl(tracker, full_curl_degrees)]))
	sample_hand(hand, _time, delta, tracked, palm, velocity, velocity_valid)
	_log_changes(hand)

## Prints when a hand switches input (HAND / CONTROLLER / BOTH / NONE) or tracking confidence,
## so the simultaneous test can be timed from logcat.
func _log_changes(hand: Hand) -> void:
	var input := hand.input_name()
	if input != hand.last_input:
		print("HANDTEST input %s t=%.2f %s -> %s source=%s" % [
			hand.side, _time, hand.last_input if hand.last_input else "start", input, _source_name(hand.source),
		])
		hand.last_input = input
	if hand.present and hand.confidence != hand.last_confidence:
		print("HANDTEST conf %s t=%.2f %s joints=%d" % [hand.side, _time, _confidence_name(hand.confidence), hand.joints_tracked])
		hand.last_confidence = hand.confidence

## One step of the drop, jump, punch, and peak measurement. Split from _process so the
## validation runner can feed it a recorded motion.
func sample_hand(hand: Hand, now: float, delta: float, tracked: bool, palm: Vector3,
		reported: Vector3, reported_valid: bool) -> void:
	if hand.tracked and not tracked:
		hand.drops += 1
		if hand.in_punch:
			hand.punch_dropped = true
		print("HANDTEST drop %s t=%.2f moving=%.2f view=%+.0f,%+.0f curl=%.2f" % [
			hand.side, now, hand.computed_speed, hand.view.x, hand.view.y, hand.curl,
		])
	hand.tracked = tracked
	if not tracked:
		hand.has_last = false
		hand.reported_valid = false
		hand.reported_speed = 0.0
		hand.computed_speed = 0.0
		hand.lost_seconds += delta
		if hand.in_punch and hand.lost_seconds >= punch_lost_seconds:
			_end_punch(hand, now)
		_record(hand, now)
		return
	hand.lost_seconds = 0.0
	# On Quest the runtime reports 50 to 130 m/s for a frame or two when it picks a hand up.
	if reported_valid and reported.length() > jump_speed:
		hand.jumps += 1
		print("HANDTEST jump %s t=%.2f %.2f m/s reported" % [hand.side, now, reported.length()])
		reported_valid = false
	hand.reported_valid = reported_valid
	hand.reported_speed = reported.length() if reported_valid else 0.0
	hand.computed_speed = 0.0
	if hand.has_last and delta > 0.0:
		var speed := palm.distance_to(hand.last_palm) / delta
		if speed > jump_speed:
			hand.jumps += 1
			print("HANDTEST jump %s t=%.2f %.2f m/s" % [hand.side, now, speed])
		else:
			hand.computed_speed = speed
	hand.last_palm = palm
	hand.has_last = true
	_record(hand, now)
	var speed := maxf(hand.reported_speed, hand.computed_speed)
	if not hand.in_punch and speed >= punch_start_speed:
		hand.in_punch = true
		hand.punch_dropped = false
		hand.punch_peak_reported = 0.0
		hand.punch_peak_computed = 0.0
		hand.punch_min_curl = hand.curl
	if hand.in_punch:
		hand.punch_min_curl = minf(hand.punch_min_curl, hand.curl)
		hand.punch_peak_reported = maxf(hand.punch_peak_reported, hand.reported_speed)
		hand.punch_peak_computed = maxf(hand.punch_peak_computed, hand.computed_speed)
		if speed < punch_end_speed:
			_end_punch(hand, now)

## Mean curl of index, middle, ring, and pinky; the thumb is left out.
func set_curl(hand: Hand, curls: PackedFloat32Array) -> void:
	var total := 0.0
	for value in curls:
		total += value
	hand.curl = total / maxf(curls.size(), 1.0)
	hand.fist = hand.curl >= fist_curl

## Curl of one finger from 0 (straight) to 1 (fully bent), from its metacarpal, proximal,
## intermediate, distal, and tip joint positions: the bend at its three knuckles, added up.
func finger_curl(points: PackedVector3Array) -> float:
	return TrackedHands.finger_curl(points, full_curl_degrees)

func reset_counters() -> void:
	for hand in hands:
		hand.reset_counters()
	print("HANDTEST reset t=%.2f" % _time)

func simultaneous_supported() -> bool:
	return _tracked_hands != null and _tracked_hands.simultaneous_supported()

## TrackedHands resumes simultaneous tracking at every session start; this pauses it for a
## hands-only run (test 7) and resumes it again.
func toggle_simultaneous() -> void:
	if not simultaneous_supported():
		print("HANDTEST simultaneous not supported")
		return
	_tracked_hands.set_simultaneous(not _tracked_hands.simultaneous_running)
	print("HANDTEST simultaneous %s t=%.2f" % ["on" if _tracked_hands.simultaneous_running else "off", _time])

func debug_text() -> String:
	var simultaneous := "ON" if _tracked_hands and _tracked_hands.simultaneous_running else "off"
	if not simultaneous_supported():
		simultaneous = "unsupported"
	var lines := PackedStringArray([
		"HAND TRACKING PROBE   simultaneous: %s" % simultaneous,
		"L stick: simultaneous   R stick: reset",
	])
	for hand in hands:
		lines.append("")
		lines.append("%s  using %s" % [String(hand.side).to_upper(), hand.input_name()])
		if not hand.present:
			lines.append("  no hand tracker (is hand tracking on in this build?)")
		else:
			lines.append("  %s  %s  conf %s  joints %d/%d" % [
				"TRACKED" if hand.tracked else "LOST",
				_source_name(hand.source),
				_confidence_name(hand.confidence),
				hand.joints_tracked,
				XRHandTracker.HAND_JOINT_MAX,
			])
			lines.append("  palm %s rep  %.2f calc   curl %d%% %s" % [
				"%.2f" % hand.reported_speed if hand.reported_valid else " -- ",
				hand.computed_speed,
				int(round(hand.curl * 100.0)),
				"FIST" if hand.fist else "open",
			])
			lines.append("  peak %.0fs  %.2f rep  %.2f calc" % [peak_window_seconds, hand.peak_reported, hand.peak_computed])
			lines.append("  punches %d  dropped %d   drops %d  jumps %d" % [
				hand.punches, hand.dropped_punches, hand.drops, hand.jumps,
			])
		lines.append("  controller %s %s" % [
			"tracked" if hand.controller_tracked else "not tracked",
			hand.controller_profile,
		])
	return "\n".join(lines)

func _record(hand: Hand, now: float) -> void:
	hand.history.append(Vector3(now, hand.reported_speed, hand.computed_speed))
	var keep := 0
	while keep < hand.history.size() and hand.history[keep].x < now - peak_window_seconds:
		keep += 1
	if keep > 0:
		hand.history = hand.history.slice(keep)
	hand.peak_reported = 0.0
	hand.peak_computed = 0.0
	for entry in hand.history:
		hand.peak_reported = maxf(hand.peak_reported, entry.y)
		hand.peak_computed = maxf(hand.peak_computed, entry.z)

func _end_punch(hand: Hand, now: float) -> void:
	hand.in_punch = false
	if hand.punch_peak_computed < punch_speed and hand.punch_peak_reported < punch_speed and not hand.punch_dropped:
		return
	hand.punches += 1
	if hand.punch_dropped:
		hand.dropped_punches += 1
	print("HANDTEST punch %s t=%.2f peak_rep=%.2f peak_calc=%.2f dropped=%s min_curl=%.2f view=%+.0f,%+.0f" % [
		hand.side, now, hand.punch_peak_reported, hand.punch_peak_computed, hand.punch_dropped,
		hand.punch_min_curl, hand.view.x, hand.view.y,
	])

func _palm_marker(hand: Hand) -> XRNode3D:
	var node := XRNode3D.new()
	node.name = "%sPalmMarker" % String(hand.side).capitalize()
	node.tracker = hand.hand_tracker_name
	node.pose = &"default"
	node.show_when_tracked = true
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.025
	sphere.height = 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.78, 0.08) if hand.side == &"left" else Color(0.05, 0.55, 1.0)
	sphere.material = material
	mesh.mesh = sphere
	node.add_child(mesh)
	return node

func _on_left_button(button: String) -> void:
	if button == "primary_click":
		toggle_simultaneous()

func _on_right_button(button: String) -> void:
	if button == "primary_click":
		reset_counters()

func _source_name(source: int) -> String:
	match source:
		XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED:
			return "optical"
		XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER:
			return "from-controller"
		XRHandTracker.HAND_TRACKING_SOURCE_NOT_TRACKED:
			return "not-tracked"
	return "source?"

func _confidence_name(confidence: int) -> String:
	match confidence:
		XRPose.XR_TRACKING_CONFIDENCE_HIGH:
			return "HIGH"
		XRPose.XR_TRACKING_CONFIDENCE_LOW:
			return "LOW"
	return "NONE"
