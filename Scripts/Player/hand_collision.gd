extends XRController3D
class_name CombatHandController

## Strikes need the controller in the hand: grip held and moving fast. When the player lets the
## controller hang on its strap, the hand is free (TrackedHands): the glove, gauntlet, and the
## rest of this node's visuals leave the hanging controller and ride the tracked palm, the hand
## cannot strike, and a pinch stands in for the trigger in menus. Gripping the controller again
## brings them back. Tracked hands lost 4 to 10 of 20 full-speed punches on Quest 3 (2026-10-14),
## so they never strike; see decision 39 in development/Exercise_Mechanics_Exploration.md.
##
## This node itself stays on the controller tracker, so buttons and haptics keep working.

## The controller's pose ("default", bound to the aim pose) in the hand frame (TrackedHands.hand_frame)
## of a hand the runtime builds around a held controller. TrackedHands measures it live while the
## controller is held; these are the steady Quest 3 values (2026-10-17), for a hand freed before any
## measurement: about 18 degrees of yaw, the aim pose 6 cm toward the thumb side and 3 cm up.
const GRIP_IN_PALM_LEFT := Transform3D(Basis(Vector3(0.94, -0.14, 0.3), Vector3(0.12, 0.99, 0.09), Vector3(-0.3, -0.04, 0.95)), Vector3(0.062, 0.034, -0.03))
const GRIP_IN_PALM_RIGHT := Transform3D(Basis(Vector3(0.94, 0.15, -0.31), Vector3(-0.13, 0.99, 0.09), Vector3(0.32, -0.04, 0.95)), Vector3(-0.062, 0.034, -0.029))
## XRToolsHand target priority while the hand is free; above any grab point.
const FREE_TARGET_PRIORITY := 1000

@export var hand_id: StringName = &"left"
@export var punch_strength_threshold: float = 1.0
@export_range(0.1, 20.0, 0.1) var max_punch_velocity: float = 10.0
## Thumb tip to index tip closer than this (m) is a pinch, and it ends past `pinch_release`.
@export var pinch_distance: float = 0.015
@export var pinch_release: float = 0.03

var punch_area: Area3D
var current_velocity: Vector3
## True while the controller hangs and the visuals ride the tracked hand.
var hand_free: bool = false
var _strike_active: bool = false
var _last_target_id: int = 0
var _last_hit_msec: int = 0
var _hands: TrackedHands
## Where the controller would be if it were in the free hand; the visuals follow it.
var _free_anchor: Node3D
var _grip_in_palm: Transform3D = Transform3D.IDENTITY
var _rest: Dictionary = {}
var _gloves: Array[XRToolsHand] = []
var _pinching: bool = false
var _debug_clock: float = 0.0

func _ready() -> void:
	punch_area = Area3D.new()
	punch_area.name = "PunchArea"
	var collision_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.075
	collision_shape.shape = sphere_shape
	punch_area.add_child(collision_shape)
	add_child(punch_area)
	punch_area.collision_layer = 2
	punch_area.collision_mask = 4
	punch_area.monitoring = true
	punch_area.body_entered.connect(_on_punch_area_body_entered)
	_free_anchor = Node3D.new()
	_free_anchor.name = "FreeHandAnchor"
	_free_anchor.top_level = true
	add_child(_free_anchor)
	add_to_group("%s_hand" % hand_id)
	_hands = get_parent().get_node_or_null("TrackedHands") as TrackedHands
	if _hands:
		_hands.hand_freed.connect(_on_hand_freed)

func _process(delta: float) -> void:
	if not hand_free or _hands == null:
		return
	_place_free_visuals()
	_debug_clock -= delta
	if OS.is_debug_build() and _debug_clock <= 0.0:
		_debug_clock = 1.0
		_log_free_placement()
	var gap := _hands.pinch_gap(hand_id)
	var pinching := gap >= 0.0 and gap < (pinch_release if _pinching else pinch_distance)
	if pinching != _pinching:
		_pinching = pinching
		if pinching:
			button_pressed.emit("trigger_click")
		else:
			button_released.emit("trigger_click")

## The menu trigger: the controller's trigger, or a pinch while the controller hangs.
func is_menu_trigger_down() -> bool:
	return _pinching if hand_free else is_button_pressed("trigger_click")

## Finger curl of the free hand, 0 open to 1 a fist; -1 while the controller is held.
func free_hand_curl() -> float:
	return _hands.curl(hand_id) if hand_free and _hands else -1.0

func _on_hand_freed(side: StringName, free: bool) -> void:
	if side == hand_id:
		set_hand_free(free)

## Moves the visuals between the controller and the tracked hand. On the hand they sit where they
## would sit on a controller held in it: the XRToolsHand glove targets the anchor, and the other
## visuals go top-level and follow it.
func set_hand_free(free: bool) -> void:
	if free == hand_free:
		return
	hand_free = free
	if not free and _pinching:
		_pinching = false
		button_released.emit("trigger_click")
	_grip_in_palm = GRIP_IN_PALM_LEFT if hand_id == &"left" else GRIP_IN_PALM_RIGHT
	if _hands and _hands.has_grip_in_palm(hand_id):
		_grip_in_palm = _hands.grip_in_palm(hand_id)
	_grip_in_palm = _grip_in_palm.orthonormalized()
	for child in get_children():
		var node := child as Node3D
		if node == null or node == punch_area or node == _free_anchor:
			continue
		if node is XRToolsHand:
			var glove := node as XRToolsHand
			if free:
				glove.add_target_override(_free_anchor, FREE_TARGET_PRIORITY)
				_gloves.append(glove)
			else:
				glove.remove_target_override(_free_anchor)
				glove.force_grip_trigger()
			continue
		if free:
			_rest[node] = node.transform
			node.top_level = true
		elif _rest.has(node):
			node.top_level = false
			node.transform = _rest[node]
	if not free:
		_gloves.clear()
	if free:
		_place_free_visuals()

## Where the controller would be, held in the free hand, and the top-level visuals around it.
func _place_free_visuals() -> void:
	var origin := get_parent() as Node3D
	var origin_transform := origin.global_transform if origin else Transform3D.IDENTITY
	var palm := _hands.palm(hand_id) if _hands else Transform3D.IDENTITY
	_free_anchor.global_transform = origin_transform * palm * _grip_in_palm
	for node in _rest:
		if is_instance_valid(node) and node.top_level:
			node.global_transform = _free_anchor.global_transform * _rest[node]
	# The glove's fingers follow the tracked fingers: XR Tools animates them from grip and trigger.
	var curl := _hands.curl(hand_id) if _hands else 0.0
	for glove in _gloves:
		if is_instance_valid(glove):
			glove.force_grip_trigger(curl, curl)

func _physics_process(_delta: float) -> void:
	var pose := get_pose()
	current_velocity = _world_velocity(pose.linear_velocity) if pose else Vector3.ZERO
	_strike_active = not hand_free and is_button_pressed("grip_click") and current_velocity.length() > punch_strength_threshold
	if not _strike_active:
		_last_target_id = 0
		return
	for body in punch_area.get_overlapping_bodies():
		_try_strike(body)

## XRPose.linear_velocity stays in the raw OpenXR play space: Godot turns the pose's transform by
## XRServer's reference frame (moved by center_on_hmd on the Meta recenter) and the origin, but
## not its velocity, so the velocity takes the same turn here or the fling goes sideways.
## https://docs.godotengine.org/en/stable/classes/class_xrpose.html#class-xrpose-method-get-adjusted-transform
func _world_velocity(play_space_velocity: Vector3) -> Vector3:
	var origin := get_parent() as Node3D
	var origin_basis := origin.global_basis if origin else Basis.IDENTITY
	return origin_basis * (XRServer.get_reference_frame().basis * play_space_velocity) * XRServer.world_scale

func _on_punch_area_body_entered(body: Node3D) -> void:
	_try_strike(body)

func _try_strike(body: Node3D) -> void:
	if not _strike_active or not body.has_method("receive_strike"):
		return
	var round := get_tree().get_first_node_in_group("RoundController") as RoundController
	if round and not round.is_round_active():
		return
	var now := Time.get_ticks_msec()
	if body.get_instance_id() == _last_target_id and now - _last_hit_msec < 250:
		return
	_last_target_id = body.get_instance_id()
	_last_hit_msec = now
	var speed := current_velocity.length()
	var strike := {
		"hand_id": hand_id,
		"speed": speed,
		"position": global_position,
		"direction": current_velocity.normalized(),
		"quality": clampf((speed - punch_strength_threshold) / maxf(max_punch_velocity - punch_strength_threshold, 0.1), 0.0, 1.0),
	}
	var result: Dictionary = body.receive_strike(strike)
	var kind: StringName = result.get("resolution_kind", &"")
	if kind == &"block_half":
		_pulse_hand(0.7, 0.12)
	elif result.get("valid", false):
		var sweet: bool = result.get("sweet_spot", false)
		var on_beat: bool = result.get("on_beat", false)
		# A harder punch lands harder in the hand, as it does in the rift.
		_pulse_hand(lerpf(0.75, 1.0, float(result.get("power", 1.0))), 0.22 if sweet or on_beat else 0.16)
	else:
		_pulse_hand(0.4 if kind == &"not_open" else 0.55, 0.07)

func _pulse_hand(magnitude: float, duration_sec: float) -> void:
	## OpenXR haptic on the punching controller, the same frame the strike resolves.
	## https://docs.godotengine.org/en/stable/classes/class_xrinterface.html#class-xrinterface-method-trigger-haptic-pulse
	var amplitude := clampf(magnitude * XRToolsUserSettings.haptics_scale, 0.0, 1.0)
	var interface := XRServer.primary_interface
	if interface and amplitude > 0.0:
		interface.trigger_haptic_pulse(&"haptic", tracker, 0.0, amplitude, duration_sec, 0.0)
	var rumble_event := XRToolsRumbleEvent.new()
	rumble_event.magnitude = clampf(magnitude, 0.0, 1.0)
	rumble_event.duration_ms = int(duration_sec * 1000.0)
	rumble_event.active_during_pause = false
	rumble_event.indefinite = false
	XRToolsRumbleManager.add("combat_%s_%s" % [hand_id, Time.get_ticks_usec()], rumble_event, [tracker])

## Debug builds: where the free hand's visuals went, in head space (x right, y up, -z ahead), so
## a held pose on the headset can be checked against the log.
func _log_free_placement() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin := get_parent() as Node3D
	var head := camera.global_transform.affine_inverse()
	var frame := head * (origin.global_transform if origin else Transform3D.IDENTITY) * _hands.palm(hand_id)
	var anchor := head * _free_anchor.global_transform
	var parts := PackedStringArray()
	for node in _rest:
		if is_instance_valid(node):
			var placed := head * (node as Node3D).global_transform
			parts.append("%s top=%s at=%s fwd=%s" % [node.name, node.top_level, placed.origin.snapped(Vector3.ONE * 0.01),
				(-placed.basis.z).normalized().snapped(Vector3.ONE * 0.1)])
	for glove in _gloves:
		var placed := head * glove.global_transform
		parts.append("%s at=%s fwd=%s" % [glove.name, placed.origin.snapped(Vector3.ONE * 0.01), (-placed.basis.z).normalized().snapped(Vector3.ONE * 0.1)])
	print("HANDS place %s frame at=%s fwd=%s thumb=%s | anchor at=%s fwd=%s thumb=%s | %s" % [hand_id,
		frame.origin.snapped(Vector3.ONE * 0.01), (-frame.basis.z).snapped(Vector3.ONE * 0.1), frame.basis.y.snapped(Vector3.ONE * 0.1),
		anchor.origin.snapped(Vector3.ONE * 0.01), (-anchor.basis.z).normalized().snapped(Vector3.ONE * 0.1),
		anchor.basis.y.normalized().snapped(Vector3.ONE * 0.1), " | ".join(parts)])
